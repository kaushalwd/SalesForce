@isTest
public class UnitSearchLwcControllerFROMSRTest {
    @TestSetup
    public static void testSetup(){
        String offerLinesListStr =''; 
        
        // Create Person Account
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account personAcc = new Account(LastName = 'Test Person', RecordTypeId = personRtId, PersonEmail='test@gmail.com');
        insert personAcc;
        
        // Create Business Account (OrganizationAccount) and Contact
        Id businessRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        Account businessAcc = new Account(Name = 'Test Business', RecordTypeId = businessRtId);
        insert businessAcc;
        
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = businessAcc.Id,
            Email = 'test@example.com',
            Is_Active__c = true
        );
        insert con;
        
        Project__c project = new Project__c();
        insert project;
        
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        
        insert  vaObj;
        
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        phase.PhaseOptions__c =options;
        
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Status__c = 'Available';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '6';
        insert unit;
        
        Unit_Option__c unitOp = new Unit_Option__c();
        unitOp.Phase__c = phase.Id;
        unitOp.PlotAreasqm__c = 1.0;
        unitOp.PlotNo__c = '1';
        unitOp.Unit__c =unit.id;
        insert unitOp;        
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        paymentPlan.Status__c = 'Active';
        paymentPlan.StartDate__c = system.today().addDays(-2);
        paymentPlan.ExpiryDate__c = system.today().addDays(5);
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        
        insert installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        insert oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.TotalAmount__c = 1000000;
        so.CustomerAccount__c = businessAcc.Id;
        so.Status__c = 'Sold';
        
        insert so;
        
        //UnitSearchLwcController clsObj = new UnitSearchLwcController();
        ServiceRequest__c serviceRequestUnit = new ServiceRequest__c();
        serviceRequestUnit.Status__c = 'In-progress';
        serviceRequestUnit.AccountId__c = personAcc.Id; 
        serviceRequestUnit.SalesOrder__c = so.Id;
        serviceRequestUnit.Transferred_Sales_Order__c = so.Id;
        serviceRequestUnit.RecordTypeId= schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('Service_Request_Management_Unit_Upgrade').getRecordTypeId();
        
        insert serviceRequestUnit;
    }
    
    
    @isTest
    static void testcheckExistingSalesOrder()  {
        ServiceRequest__c thisRequest = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        
        Test.startTest();
        Boolean thisSalesOrder = UnitSearchLwcControllerFromSR.checkExistingSalesOrder(thisRequest.Id);
        
        Test.stopTest();
    }
    
    
    @isTest
    static void testupdateServiceRequest()  {
        ServiceRequest__c thisRequest = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        Unit__c thisUnit = [SELECT Id FROM Unit__c LIMIT 1];
        PaymentPlan__c thisPlan = [SELECT Id FROM PaymentPlan__c LIMIT 1];
        Project__c thisProject = [SELECT Id,Name FROM Project__c LIMIT 1];
        String message = UnitSearchLwcControllerFromSR.updateServiceRequest(thisUnit.Id, thisPlan.Id, thisRequest.Id);
        list<map<String,string>> test = UnitSearchLwcControllerFromSR.populateProjectsforSR(thisProject.Id);
        ServiceRequest__c requests = UnitSearchLwcControllerFromSR.getSalesOrderfromServiceReqeust(thisRequest.Id);
        test = UnitSearchLwcControllerFromSR.getAllProjects();
    }
    
    @isTest
    static void TestSendSalesOfferPDF()  {
        ServiceRequest__c thisRequest = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        Unit__c thisUnit = [SELECT Id FROM Unit__c LIMIT 1];
        List<String> units = new List<String>{thisUnit.Id};
        PaymentPlan__c thisPlan = [SELECT Id FROM PaymentPlan__c LIMIT 1];
        Project__c thisProject = [SELECT Id,Name FROM Project__c LIMIT 1];
        Phase__c thisPhase = [SELECT Id FROM Phase__c LIMIT 1];
        Opportunity thisOpp = [SELECT Id FROM Opportunity   LIMIT 1];
        List<SalesOrder__c> sos = [SELECT Id, PaymentPlan__c, TotalAmount__c, Opportunity__c FROM SalesOrder__c WHERE Opportunity__c=:thisOpp.Id ];
        Test.startTest();
        UnitSearchLwcControllerFromSR.sendSalesOfferPDF(String.valueOf(thisUnit.Id),'test', String.valueOf(thisOpp.Id), 'test', '', '');
        String mesg = UnitSearchLwcControllerFromSR.saveBlockedUnits(units, String.valueOf(thisOpp.Id), '', '');
        UnitSearchLwcControllerFromSR.getEOIDetails(String.valueOf(thisOpp.Id));
        UnitSearchLwcControllerFromSR.createPaymentInstallments(sos);
        UnitSearchLwcControllerFromSR.updateUnitsAsBlocked(units, String.valueOf(thisOpp.Id));
        UnitSearchLwcControllerFromSR.checkUnitStatus(units);
        UnitSearchLwcControllerFromSR.unblockSelectedUnits(units); 
        List<Unit__c> s =UnitSearchLwcControllerFromSR.getUnitDetailsforPhase(thisPhase.Id, 250);
        List<Unit__c> s1 =UnitSearchLwcControllerFromSR.getUnitDetails(thisPhase.Id, String.valueOf(thisOpp.Id));

        Test.stopTest();
    }  
    
    @isTest
    static void TestGenerateSalesOffer()  {
        ServiceRequest__c thisRequest = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        Unit__c thisUnit = [SELECT Id FROM Unit__c LIMIT 1];
        Phase__c thisPhase = [SELECT Id FROM Phase__c LIMIT 1];
        Test.startTest();
        UnitSearchLwcControllerFromSR.UnitDetailsWrapper tests = UnitSearchLwcControllerFromSR.generateSalesOffer(thisUnit.Id);
        list<map<String,string>> testrecord = UnitSearchLwcControllerFromSR.getAllBuildings(thisPhase.Id);
        list<map<String,string>> buh = UnitSearchLwcControllerFromSR.getBlockingHours();
        Test.stopTest();
    } 
    
    @isTest
    static void testSaveSalesOrder() {
        // Reuse @TestSetup data to avoid Account duplicate-rule failures
        // (same Name/Email as setup was causing DUPLICATES_DETECTED).
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        PaymentPlan__c paymentPlan = [SELECT Id FROM PaymentPlan__c LIMIT 1];
        VirtualAccount__c vaObj = [SELECT Id FROM VirtualAccount__c LIMIT 1];
        Account businessAcc = [
            SELECT Id
            FROM Account
            WHERE RecordType.DeveloperName = 'OrganizationAccount'
            LIMIT 1
        ];
        Opportunity oppObj = [SELECT Id FROM Opportunity LIMIT 1];

        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.VirtualAccount__c = vaObj.Id;
        so.TotalAmount__c = 1000000;
        so.CustomerAccount__c = businessAcc.Id;
        so.Status__c = 'Sold';
        insert so;

        Test.startTest();
        UnitSearchLwcControllerFromSR.saveSalesOrder(
            new List<SalesOrder__c>{ so },
            String.valueOf(oppObj.Id),
            null
        );
        String jsonTest = '[{"unitId":"' + unit.Id + '","offerLinesLst":[]}]';
        UnitSearchLwcControllerFromSR.createOfferLineCollection(
            new List<SalesOrder__c>{ so },
            oppObj.Id,
            jsonTest
        );
        Test.stopTest();
    }

    @isTest
    static void testAdditionalCoveragePaths() {
        Unit__c unit = [SELECT Id, Phase__c FROM Unit__c LIMIT 1];
        Phase__c phase = [SELECT Id, Project__c, EscrowAccount__c FROM Phase__c LIMIT 1];
        Project__c extraProject = new Project__c(Name = 'Other Project');
        insert extraProject;
        PaymentPlan__c paymentPlan = [SELECT Id FROM PaymentPlan__c LIMIT 1];
        VirtualAccount__c vaObj = [SELECT Id FROM VirtualAccount__c LIMIT 1];
        Account businessAcc = [
            SELECT Id FROM Account WHERE RecordType.DeveloperName = 'OrganizationAccount' LIMIT 1
        ];
        Id upgradeRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Unit_Upgrade').getRecordTypeId();

        Opportunity freshOpp = new Opportunity(
            Name = 'Fresh SO Opp',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today(),
            AccountId = businessAcc.Id,
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates'
        );
        insert freshOpp;

        ServiceRequest__c srNoSo = new ServiceRequest__c(
            Status__c = 'In-progress',
            AccountId__c = businessAcc.Id,
            RecordTypeId = upgradeRtId
        );
        insert srNoSo;

        Unit__c bookingUnit = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 2.0,
            PlotNo__c = '99',
            Status__c = 'Available',
            Sub_Status__c = 'Un-Assigned',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1'
        );
        insert bookingUnit;

        SalesOrder__c pendingSo = new SalesOrder__c(
            Unit__c = bookingUnit.Id,
            PaymentPlan__c = paymentPlan.Id,
            VirtualAccount__c = vaObj.Id,
            TotalAmount__c = 1000000,
            CustomerAccount__c = businessAcc.Id
        );

        OffersPromotions__c promo = new OffersPromotions__c(
            Project__c = phase.Project__c,
            Name = 'SR Offer',
            OfferName__c = 'SR Offer',
            StartDate__c = Date.today(),
            EndDate__c = Date.today().addDays(30),
            Approval_Status__c = 'Approved',
            SalesEventCampaignName__c = 'SR Offer'
        );
        insert promo;
        OfferLines__c offerLine = new OfferLines__c(
            OfferName__c = promo.Id,
            OfferType__c = 'Waiver',
            OfferOn__c = 'ADM Fees',
            OfferValueType__c = '%',
            OfferValue__c = 1,
            Offer_Line_Approval_Status__c = 'Approved',
            Is_Default_Offer__c = true,
            IsActive__c = true
        );
        insert offerLine;

        Test.startTest();
        System.assertEquals(false, UnitSearchLwcControllerFromSR.checkExistingSalesOrder(srNoSo.Id));
        try {
            UnitSearchLwcControllerFromSR.updateServiceRequest(unit.Id, paymentPlan.Id, unit.Id);
        } catch (Exception ex) {
            System.debug('updateServiceRequest error: ' + ex.getMessage());
        }
        System.assert(!UnitSearchLwcControllerFromSR.populateProjectsforSR(phase.Project__c).isEmpty());
        System.assertNotEquals(null, UnitSearchLwcControllerFromSR.getAllBuildings(phase.Project__c));
        UnitSearchLwcControllerFromSR.getUnitDetailsforPhase(phase.Id, null);
        UnitSearchLwcControllerFromSR.getUnitDetailsforPhase(phase.Id, 0);

        String offerJson = '[{"unitId":"' + bookingUnit.Id + '","offerLinesLst":[{"Id":"' + offerLine.Id + '"}]}]';
        try {
            UnitSearchLwcControllerFromSR.saveSalesOrder(
                new List<SalesOrder__c>{ pendingSo },
                String.valueOf(freshOpp.Id),
                offerJson
            );
        } catch (Exception ex) {
            System.debug('saveSalesOrder coverage: ' + ex.getMessage());
        }

        insert new Block_Request__c(
            Unit__c = unit.Id,
            Opportunity__c = freshOpp.Id,
            Status__c = 'In Progress',
            Hourstoblock__c = '24'
        );
        UnitSearchLwcControllerFromSR.saveBlockedUnits(new List<String>{ unit.Id }, freshOpp.Id, 'c', '24');

        Unit__c reservedUnit = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 3.0,
            PlotNo__c = '88',
            Status__c = 'Reserved',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1'
        );
        insert reservedUnit;
        UnitSearchLwcControllerFromSR.saveBlockedUnits(new List<String>{ reservedUnit.Id }, freshOpp.Id, 'c', '24');

        unit.Status__c = 'Available';
        unit.Sub_Status__c = 'Assigned';
        unit.BlockedFor__c = UserInfo.getUserId();
        unit.BlockedBy__c = UserInfo.getUserId();
        update unit;
        UnitSearchLwcControllerFromSR.updateUnitsAsBlocked(new List<String>{ unit.Id }, freshOpp.Id);
        UnitSearchLwcControllerFromSR.checkUnitStatus(new List<String>{ unit.Id });

        User otherUser = [SELECT Id FROM User WHERE Id != :UserInfo.getUserId() AND IsActive = true LIMIT 1];
        unit.BlockedFor__c = otherUser.Id;
        update unit;
        UnitSearchLwcControllerFromSR.checkUnitStatus(new List<String>{ unit.Id });
        UnitSearchLwcControllerFromSR.updateUnitsAsBlocked(new List<String>{ unit.Id }, freshOpp.Id);

        SalesOrder__c soForOffers = [SELECT Id, Unit__c FROM SalesOrder__c LIMIT 1];
        UnitSearchLwcControllerFromSR.createOfferLineCollection(
            new List<SalesOrder__c>{ soForOffers },
            freshOpp.Id,
            offerJson.replace(bookingUnit.Id, soForOffers.Unit__c)
        );
        Test.stopTest();
    }
}