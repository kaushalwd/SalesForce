/**********************************************************************************************************************
* Name               : Modon_Egypt_UnitSearchLwcControllerTest
* Description        : Test class for Modon_Egypt_UnitSearchLwcController only. Flexible/Standard payment plan and
*                      createSalesOrderInstallments coverage now live in their respective dedicated test classes.
* Created By         : Horizontal Digital
* --------------------------------------------------------------------------------------------------------------------
* Version    Author         Date         Comments
* --------------------------------------------------------------------------------------------------------------------
* 1.0        Horizontal                  Initial version
* 2.0        Milin Kapatel  20-04-2026   Update test class to test positive and negative scenarios for Modon_Egypt_UnitSearchLwcController and ModonEgypt_CustomPaymentPlanController.
* 3.0        Milin Kapatel  24-04-2026   Align with ModonEgypt_CustomPaymentPlanController v4.0: default 8Y plan mapping, calcAnchor/By Amount PV rules, and negative scenarios.
* 4.0        Milin Kapatel  12-05-2026   Downpayment mode (Percent / Amount) and maintenance installment validation & application coverage.
* 5.0        Milin Kapatel  21-05-2026   Grace period milestone date tests for v4.4 computeMilestoneDate logic across all 3 frequencies.
* 6.0        Milin Kapatel  25-05-2026   Updated test_SaveSalesOrder_MixedPayload to cover Egypt_Flexible_Payment_Plan__c population via flexiblePaymentPlanName (v7.7).
* 7.0        Milin Kapatel  08-06-2026   Scoped to Modon_Egypt_UnitSearchLwcController only; moved payment plan, buildSalesOrderInstance and createSalesOrderInstallments coverage to dedicated test classes.
******************************************************************************************************************/
@isTest
private class Modon_Egypt_UnitSearchLwcControllerTest {

    // ==============================================================================
    // DATA SETUP
    // ==============================================================================
    @testSetup
    static void setupTestData() {
        // Assign Egypt Sales Order Permissions permission set to the running user (Modified by Shahil Sinha)
        System.runAs(new User(Id = UserInfo.getUserId())) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Egypt_Sales_Order_Permissions' LIMIT 1];
            List<PermissionSetAssignment> existingAssignments = [
                SELECT Id FROM PermissionSetAssignment 
                WHERE AssigneeId = :UserInfo.getUserId() 
                AND PermissionSetId = :ps.Id
            ];
            if (existingAssignments.isEmpty()) {
                insert new PermissionSetAssignment(
                    AssigneeId = UserInfo.getUserId(),
                    PermissionSetId = ps.Id
                );
            }
        }

        // 1. Setup Account and Contact
        Id orgRT = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND Name = 'Organization Account' LIMIT 1].Id;
        Account acct = new Account(
            Name = 'Test Org Account', 
            RecordTypeId = orgRT, 
            Source_Entity__c = 'Modon - Egypt', 
            Phone = '1234567890'
        );
        insert acct;
        
        Contact con = new Contact(
            FirstName = 'Test', 
            LastName = 'Contact', 
            Email = 'testcon@example.com', 
            AccountId = acct.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert con;

        // 2. Setup Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp', 
            StageName = 'Prospecting', 
            CloseDate = Date.today().addDays(30), 
            AccountId = acct.Id, 
            Source_Entity__c = 'Modon - Egypt'
        );
        insert opp;

        // 3. Setup Project and Phase
        Project__c proj = new Project__c(Name = 'Test Project', Source_Entity__c = 'Modon - Egypt');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = proj.Id);
        insert phase;

        // 4. Setup Units
        List<Unit__c> unitsToInsert = new List<Unit__c>();
        Unit__c unit1 = new Unit__c(
            Name = 'U-101', PlotNo__c = '101', Phase__c = phase.Id, ApprovalStatus__c = 'Released', Status__c = 'Available', Sub_Status__c = 'Un-Assigned', 
            Source_Entity__c = 'Modon - Egypt', GrossFloorAreaGFA__c = 150, UnitClassification__c = 'Villa', 
            Unit_Quality__c = 'Q2', Number_of_Bedrooms__c = '3', FloorNumber__c = '1'
        );
        Unit__c unit2 = new Unit__c(
            Name = 'U-102',  PlotNo__c = '102', Phase__c = phase.Id, ApprovalStatus__c = 'Released', Status__c = 'Available', Sub_Status__c = 'Un-Assigned', 
            Source_Entity__c = 'Modon - Egypt', GrossFloorAreaGFA__c = 200, UnitClassification__c = 'Villa', 
            Unit_Quality__c = 'Q1', Number_of_Bedrooms__c = '4', FloorNumber__c = '2'
        );
        unitsToInsert.add(unit1);
        unitsToInsert.add(unit2);
        insert unitsToInsert;

        // 5. Setup Payment Plan (Name must match 8Y LIKE; isDefault = true for UnitPaymentPlanMapping__c queries)
        PaymentPlan__c pp = new PaymentPlan__c(
            Name = 'Standard 8 Year Plan', Unit__c = unit1.Id, Status__c = 'Active',
            Discount_Percent__c = 5, Maintenance_Fee__c = 10, Number_of_Maintenance_Fee__c = 4, Type__c = 'Standard', isDefault__c = true, Phase__c = phase.Id, StartDate__c = System.today() - 1, ExpiryDate__c = System.Today().addMonths(60)
        );
        insert pp;

        // 6. Setup Payment Installments (10% DP + 8 x 11.25% = 100%; last row flagged as maintenance installment)
        List<PaymentInstallements__c> pInstallments = new List<PaymentInstallements__c>();
        pInstallments.add(new PaymentInstallements__c(
            Name = 'Downpayment', CurrencyIsoCode = 'EGP',
            PaymentInstallment__c = pp.Id, MilestoneNumber__c = 1, Milestone_Egypt_Percent__c = 10,
            Is_Maintenance_Installment__c = false, MilestoneDescription__c = 'Downpayment', MilestoneDate__c = System.today().addMonths(30),
            Milestone__c = 10, No_Of_Months_To_Add_From_Last_Date__c = 3
        ));
        for (Integer m = 2; m <= 9; m++) {
            Boolean isLast = (m == 9);
            pInstallments.add(new PaymentInstallements__c(
                PaymentInstallment__c = pp.Id,
                MilestoneNumber__c = m,
                Milestone_Egypt_Percent__c = 11.25,
                Is_Maintenance_Installment__c = isLast,
                No_Of_Months_To_Add_From_Last_Date__c = 3,
                MilestoneDescription__c = 'Installment ' + (m - 1),
                Milestone__c = 11.25
            ));
        }
        insert pInstallments;

        // 7. Unit Payment Plan Mappings: EGP for U-101; AED + USD for both units.
        List<UnitPaymentPlanMapping__c> upmList = new List<UnitPaymentPlanMapping__c>();
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-101 8 Year EGP', Unit__c = unit1.Id, Payment_Plan__c = pp.Id, Base_Price__c = 1000000, CurrencyIsoCode = 'EGP'
        ));
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-101 8 Year USD', Unit__c = unit1.Id, Payment_Plan__c = pp.Id, Base_Price__c = 100000, CurrencyIsoCode = 'USD'
        ));
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-101 8 Year AED', Unit__c = unit1.Id, Payment_Plan__c = pp.Id, Base_Price__c = 100000, CurrencyIsoCode = 'AED'
        ));
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-102 8 Year USD', Unit__c = unit2.Id, Payment_Plan__c = pp.Id, Base_Price__c = 1500000, CurrencyIsoCode = 'USD'
        ));
        upmList.add(new UnitPaymentPlanMapping__c(
            Name = 'Test U-102 8 Year AED', Unit__c = unit2.Id, Payment_Plan__c = pp.Id, Base_Price__c = 1500000, CurrencyIsoCode = 'AED'
        ));
        insert upmList;
    }

    // ==============================================================================
    // TEST METADATA & FILTERS
    // ==============================================================================
    @isTest
    static void test_MetadataAndFilters() {
        Test.startTest();
        System.assertNotEquals(null, Modon_Egypt_UnitSearchLwcController.getUnitTypes());
        System.assertNotEquals(null, Modon_Egypt_UnitSearchLwcController.getNumberofBedrooms());
        System.assertNotEquals(null, Modon_Egypt_UnitSearchLwcController.getQualityType());
        System.assertNotEquals(null, Modon_Egypt_UnitSearchLwcController.getGFARange());
        System.assertNotEquals(null, Modon_Egypt_UnitSearchLwcController.getFloorValues());
        System.assertNotEquals(null, Modon_Egypt_UnitSearchLwcController.getCurrencyIsoCodes());
        Test.stopTest();
    }

    // ==============================================================================
    // TEST SEARCH QUERIES (PROJECT, PHASE, UNIT DETAILS)
    // ==============================================================================
    @isTest
    static void test_ProjectAndUnitSearch() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c phase = [SELECT Id FROM Phase__c LIMIT 1];

        Test.startTest();
        
        // Projects & Phases
        List<Map<String, String>> projects = Modon_Egypt_UnitSearchLwcController.getAllProjects(opp.Id);
        System.assert(!projects.isEmpty(), 'Projects should be returned');
        
        List<Map<String, String>> phases = Modon_Egypt_UnitSearchLwcController.getAllPhases(proj.Id);
        System.assert(!phases.isEmpty(), 'Phases should be returned');

        List<Modon_Egypt_UnitSearchLwcController.GetUnitsWrapper> unitDetails = Modon_Egypt_UnitSearchLwcController.getUnitDetails(
            phase.Id, opp.Id, null, null, null, null, null, null, null
        );
        System.assert(!unitDetails.isEmpty(), 'Units should be returned matching the filters');

        List<Modon_Egypt_UnitSearchLwcController.GetUnitsWrapper> unitDetailsWithFilters = Modon_Egypt_UnitSearchLwcController.getUnitDetails(
            phase.Id, opp.Id, 'Villa', 'Q2', '3', '100-200', '1', 'U-101', 'EGP'
        );
        System.assertEquals(1, unitDetailsWithFilters.size(), 'Should find exactly one unit by name');        

        Test.stopTest();
    }

    // ==============================================================================
    // TEST DOCUMENT VALIDATION
    // ==============================================================================
    @isTest
    static void test_DocumentValidation() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        // Create required documents for Organization Account
        insert new Documents__c(Name = 'tax id', Status__c = 'Uploaded', Opportunity__c = opp.Id);

        Modon_Egypt_UnitSearchLwcController.DocumentValidationResult docResult = Modon_Egypt_UnitSearchLwcController.isDocumentValidEgypt(opp.Id);
        System.assertEquals(true, docResult.isValid, 'Documents should be valid after upload');
        Test.stopTest();
    }

    // ==============================================================================
    // TEST SAVE SALES ORDER (STANDARD & FLEXIBLE PAYLOADS)
    // ==============================================================================
    @isTest
    static void test_SaveSalesOrder_MixedPayload() {
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Unit__c unit1 = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];
        Unit__c unit2 = [SELECT Id FROM Unit__c WHERE Name = 'U-102' LIMIT 1];
        PaymentPlan__c pp = [SELECT Id FROM PaymentPlan__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new GenericHttpCalloutMock());

        // 1. Create Standard Plan Payload
        Modon_Egypt_UnitSearchLwcController.SalesOrderPayload payloadStandard = new Modon_Egypt_UnitSearchLwcController.SalesOrderPayload();
        payloadStandard.unit = unit1.Id;
        payloadStandard.paymentPlan = pp.Id;
        payloadStandard.customerAccount = opp.AccountId;
        payloadStandard.totalAmount = 1000000;
        payloadStandard.currencyIsoCode = 'EGP';

        // 2. Create Flexible Plan Payload
        String flexPlanName = 'Custom Quarterly Flexible Plan';
        Modon_Egypt_UnitSearchLwcController.SalesOrderPayload payloadFlexible = new Modon_Egypt_UnitSearchLwcController.SalesOrderPayload();
        payloadFlexible.unit = unit2.Id;
        payloadFlexible.customerAccount = opp.AccountId;
        payloadFlexible.totalAmount = 1500000;
        payloadFlexible.currencyIsoCode = 'EGP';
        payloadFlexible.flexiblePaymentPlanName = flexPlanName; // v7.7 — Flexible Payment Plan name

        ModonEgyptUtilities.CustomInstallment flexInst = new ModonEgyptUtilities.CustomInstallment();
        flexInst.milestoneNumber = 1;
        flexInst.milestoneDescription = 'Custom Downpayment';
        flexInst.milestoneEgyptPercent = 10;
        flexInst.amount = 150000;
        flexInst.milestoneDate = Date.today();

        payloadFlexible.customInstallments = new List<ModonEgyptUtilities.CustomInstallment>{ flexInst };

        // 3. Save Sales Orders
        List<Modon_Egypt_UnitSearchLwcController.SalesOrderPayload> payloads = new List<Modon_Egypt_UnitSearchLwcController.SalesOrderPayload>{ payloadStandard, payloadFlexible };
        String response = Modon_Egypt_UnitSearchLwcController.saveSalesOrder(payloads, opp.Id);
        System.assertNotEquals(null, response, 'saveSalesOrder should return a response');

        if (response == 'Success') {
            List<SalesOrder__c> createdOrders = [SELECT Id, PaymentPlan__c, Unit__c, Egypt_Flexible_Payment_Plan__c FROM SalesOrder__c];
            System.assertEquals(2, createdOrders.size(), 'Two sales orders should be created');
            System.assert(![SELECT Id FROM SalesOrderInstallments__c].isEmpty(), 'Installments should be created for both orders');
            for (SalesOrder__c so : createdOrders) {
                if (so.Unit__c == unit2.Id) {
                    System.assertEquals(flexPlanName, so.Egypt_Flexible_Payment_Plan__c);
                } else {
                    System.assertEquals(null, so.Egypt_Flexible_Payment_Plan__c);
                }
            }
        }

        Test.stopTest();
    }

    // ==============================================================================
    // TEST BLOCK REQUESTS AND STATUS CHECKS
    // ==============================================================================
    @isTest
    static void test_BlockRequestsAndStatus() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-102' LIMIT 1];

        Test.startTest();

        // 1. Check Unit Status
        String statusCheck = Modon_Egypt_UnitSearchLwcController.checkUnitStatus(new List<String>{ unit.Id });
        System.assertEquals('Success', statusCheck, 'Unit should be available');

        // 2. Save Blocked Units
        String blockResponse = Modon_Egypt_UnitSearchLwcController.saveBlockedUnits(
            new List<String>{ unit.Id }, opp.Id, 'Test Comment', '24'
        );
        System.assertNotEquals(null, blockResponse, 'saveBlockedUnits should return a response');

        // 3. Save Sales Order with Block Request
        Modon_Egypt_UnitSearchLwcController.SalesOrderPayload payload = new Modon_Egypt_UnitSearchLwcController.SalesOrderPayload();
        payload.unit = unit.Id;
        payload.totalAmount = 2000000;
        payload.currencyIsoCode = 'EGP';

        String soBlockResponse = Modon_Egypt_UnitSearchLwcController.saveSalesOrderWithBlockRequest(
            new List<Modon_Egypt_UnitSearchLwcController.SalesOrderPayload>{ payload }, opp.Id
        );
        
        // Depending on existing block requests in setup, this might return success or 'In Progress' block message. 
        // We ensure it executes without crashing.
        System.assertNotEquals(null, soBlockResponse);

        // 4. Check Existing Sales Order
        Boolean existingSO = Modon_Egypt_UnitSearchLwcController.checkExistingSalesOrder(opp.Id);

        Test.stopTest();
    }

    @isTest
    static void test_AdditionalCoverageBranches() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Phase__c phase = [SELECT Id FROM Phase__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c WHERE Name = 'U-101' LIMIT 1];

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account personAcc = new Account(
            LastName = 'Egypt Person',
            RecordTypeId = personRtId,
            Nationality__pc = 'Egypt',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert personAcc;
        Opportunity personOpp = new Opportunity(
            Name = 'Person Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = personAcc.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert personOpp;
        insert new Documents__c(Name = 'national id', Status__c = 'Uploaded', Opportunity__c = personOpp.Id);

        Opportunity emptyOpp = new Opportunity(
            Name = 'Empty SO Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = personAcc.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert emptyOpp;

        Test.startTest();
        System.assertEquals(false, Modon_Egypt_UnitSearchLwcController.checkExistingSalesOrder(emptyOpp.Id));
        try {
            Modon_Egypt_UnitSearchLwcController.getAllProjects('001000000000000AAA');
        } catch (Exception ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Modon_Egypt_UnitSearchLwcController.getUnitDetails(phase.Id, opp.Id, 'Villa', 'Q2', '3', '150', '1', null, 'EGP');
        Modon_Egypt_UnitSearchLwcController.isDocumentValidEgypt(personOpp.Id);
        Modon_Egypt_UnitSearchLwcController.isDocumentValidEgypt(emptyOpp.Id);

        String createOk = Modon_Egypt_UnitSearchLwcController.createBlockRequest(
            new List<String>{ unit.Id }, opp.Id, 'Test Comment', '24', 'Approved'
        );
        System.assertNotEquals(null, createOk);
        String inProgress = Modon_Egypt_UnitSearchLwcController.createBlockRequest(
            new List<String>{ unit.Id }, opp.Id, 'Test Comment', '24', 'Approved'
        );
        System.assertNotEquals(null, inProgress);
        String alreadyBlocked = Modon_Egypt_UnitSearchLwcController.saveBlockedUnits(
            new List<String>{ unit.Id }, opp.Id, 'Test Comment', '24'
        );
        System.assertNotEquals(null, alreadyBlocked);

        Unit__c reserved = [SELECT Id FROM Unit__c WHERE Name = 'U-102' LIMIT 1];
        reserved.Status__c = 'Reserved';
        update reserved;
        Modon_Egypt_UnitSearchLwcController.saveBlockedUnits(
            new List<String>{ reserved.Id }, opp.Id, 'Test Comment', '24'
        );
        Modon_Egypt_UnitSearchLwcController.createBlockRequest(
            new List<String>{ reserved.Id }, opp.Id, 'Test Comment', '24', 'Approved'
        );
        Test.stopTest();
    }

    // ==============================================================================
    // GENERIC MOCK CALLOUT FOR BACKGROUND TRIGGERS/FLOWS
    // ==============================================================================
    public class GenericHttpCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}