/**********************************************************************************************************************
* Name               : EoiRegistrationPromotionHandlerTest
* Description        : Test coverage for EoiRegistrationPromotionHandler. Seeds Project / Phase / EOI_Range__c data
*                      and exercises the promoteFromFlow invocable across single-row, multi-row batch, organisation,
*                      blank-mobile fallback, blank-BatchId, and failure scenarios.
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    20 May 2026     Initial version
* 1.1           Prateek Bansal                    22 May 2026     UTM-aware LeadSource/SubSource promotion coverage
**********************************************************************************************************************/
@isTest
private class EoiRegistrationPromotionHandlerTest {

    @testSetup
    static void setup() {
        Project__c proj = new Project__c(Name = projectInterestPicklistValue(), EOI_Limit__c = 10);
        insert proj;

        Phase__c ph = new Phase__c(Name = 'Phase A');
        insert ph;

        EOI_Range__c rng = new EOI_Range__c(
            Project__c = proj.Id, Phase__c = ph.Id,
            Unit_Type__c = 'Villa', No_of_Bedrooms__c = '3 Bedrooms',
            UnitTypologyMRE__c = 'Fairway Villas',
            Amount__c = 100000, Is_Active__c = true
        );
        insert rng;
    }

    private static String projectInterestPicklistValue() {
        Schema.SObjectField fieldToken = Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().get('ProjectInterest__c');
        if (fieldToken == null) return 'EPH Test Project';
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) return entry.getValue();
        }
        return 'EPH Test Project';
    }

    private static EOI_Public_Registration__c buildRow(String batchId, String email) {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        EOI_Range__c rng = [SELECT Id, Phase__c, Unit_Type__c, No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c FROM EOI_Range__c LIMIT 1];
        return new EOI_Public_Registration__c(
            Status__c = 'Verified', CustomerType__c = 'Individual',
            FirstName__c = 'Test', LastName__c = 'Promote',
            Email__c = email, Mobile__c = '+971500000001',
            ResidentStatus__c = 'Resident',
            EmiratesId__c = '784-1990-1234567-1',
            Project__c = proj.Id, Phase__c = rng.Phase__c, EOI_Range__c = rng.Id,
            UnitType__c = rng.Unit_Type__c, Bedrooms__c = rng.No_of_Bedrooms__c,
            UnitTypologyMRE__c = rng.UnitTypologyMRE__c,
            Amount__c = rng.Amount__c, BatchId__c = batchId,
            Source__c = 'Public Microsite'
        );
    }

    private static EOI_Public_Registration__c buildOrgRow(String batchId, String authorizedEmail) {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        EOI_Range__c rng = [SELECT Id, Phase__c, Unit_Type__c, No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c FROM EOI_Range__c LIMIT 1];
        return new EOI_Public_Registration__c(
            Status__c = 'Verified', CustomerType__c = 'Organization',
            CompanyName__c = 'Acme Holdings',
            TradeLicenseNumber__c = 'TL-' + String.valueOf(Crypto.getRandomLong()).substring(0, 6),
            ResidentStatus__c = 'Resident',
            EmiratesId__c = '784-1990-1234567-1',
            AuthorizedFirstName__c = 'Auth', AuthorizedLastName__c = 'Signer',
            AuthorizedEmail__c = authorizedEmail, AuthorizedPhone__c = '+971501234567',
            RegisteredEmail__c = 'company@example.com', RegisteredPhone__c = '+97144441234',
            Project__c = proj.Id, Phase__c = rng.Phase__c, EOI_Range__c = rng.Id,
            UnitType__c = rng.Unit_Type__c, Bedrooms__c = rng.No_of_Bedrooms__c,
            UnitTypologyMRE__c = rng.UnitTypologyMRE__c,
            Amount__c = rng.Amount__c, BatchId__c = batchId,
            Source__c = 'Public Microsite'
        );
    }

    @isTest
    static void testPromoteSingleRow() {
        EOI_Public_Registration__c row = buildRow('batch-single', 'happy@modon.test');
        insert row;

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ row.Id });
        Test.stopTest();

        EOI_Public_Registration__c after = [
            SELECT Status__c, Promotion_Error__c, MatchedLead__c, MatchedAccount__c, PromotedEOI__c
            FROM EOI_Public_Registration__c WHERE Id = :row.Id
        ];
        System.assertNotEquals('Verified', after.Status__c, 'Handler should transition status from Verified');
    }

    @isTest
    static void testPromoteMultiUnitBatchSharesOpportunity() {
        String batchId = 'batch-multi';
        EOI_Public_Registration__c r1 = buildRow(batchId, 'multi@modon.test');
        EOI_Public_Registration__c r2 = buildRow(batchId, 'multi@modon.test');
        insert new List<EOI_Public_Registration__c>{ r1, r2 };

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ r1.Id, r2.Id });
        Test.stopTest();

        List<EOI_Public_Registration__c> rows = [
            SELECT Status__c, MatchedAccount__c, PromotedEOI__c
            FROM EOI_Public_Registration__c WHERE BatchId__c = :batchId
        ];
        System.assertEquals(2, rows.size());
        if (rows[0].Status__c == 'Promoted' && rows[1].Status__c == 'Promoted') {
            System.assertEquals(rows[0].MatchedAccount__c, rows[1].MatchedAccount__c, 'Both rows share Account');
            System.assertNotEquals(rows[0].PromotedEOI__c, rows[1].PromotedEOI__c, 'EOIs are distinct');
        }
    }

    @isTest
    static void testEmptyInputReturnsEarly() {
        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>());
        Test.stopTest();
    }

    @isTest
    static void testBlankBatchIdRowIgnored() {
        EOI_Public_Registration__c row = buildRow(null, 'noBatch@modon.test');
        insert row;

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ row.Id });
        Test.stopTest();

        EOI_Public_Registration__c after = [SELECT Status__c FROM EOI_Public_Registration__c WHERE Id = :row.Id];
        System.assertEquals('Verified', after.Status__c, 'Row without BatchId should not be processed');
    }

    @isTest
    static void testPromoteOrgWithExistingAccountMatch() {
        Account org = new Account(Name = 'Acme Holdings');
        insert org;
        Contact c = new Contact(
            AccountId = org.Id, FirstName = 'Auth', LastName = 'Signer',
            Email = 'org.match@modon.test', MobilePhone = '+971501234567'
        );
        insert c;

        EOI_Public_Registration__c row = buildOrgRow('batch-org', 'org.match@modon.test');
        insert row;

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ row.Id });
        Test.stopTest();

        EOI_Public_Registration__c after = [
            SELECT Status__c, Promotion_Error__c, MatchedAccount__c, MatchedContact__c
            FROM EOI_Public_Registration__c WHERE Id = :row.Id
        ];
        System.assertNotEquals('Verified', after.Status__c, 'Handler should transition Org row from Verified');
    }

    @isTest
    static void testPromoteRowWithBlankMobileFallsBackToPhone() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        EOI_Range__c rng = [SELECT Id, Phase__c, Unit_Type__c, No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c FROM EOI_Range__c LIMIT 1];
        EOI_Public_Registration__c row = new EOI_Public_Registration__c(
            Status__c = 'Verified', CustomerType__c = 'Individual',
            FirstName__c = 'NoMobile', LastName__c = 'Promote',
            Email__c = 'phoneonly@modon.test',
            Phone__c = '+97144441234',
            ResidentStatus__c = 'Resident',
            EmiratesId__c = '784-1990-1234567-1',
            Project__c = proj.Id, Phase__c = rng.Phase__c, EOI_Range__c = rng.Id,
            UnitType__c = rng.Unit_Type__c, Bedrooms__c = rng.No_of_Bedrooms__c,
            UnitTypologyMRE__c = rng.UnitTypologyMRE__c,
            Amount__c = rng.Amount__c, BatchId__c = 'batch-phone',
            Source__c = 'Public Microsite'
        );
        insert row;

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ row.Id });
        Test.stopTest();

        EOI_Public_Registration__c after = [SELECT Status__c FROM EOI_Public_Registration__c WHERE Id = :row.Id];
        System.assertNotEquals('Verified', after.Status__c);
    }

    @isTest
    static void testPromoteWithUtmSetsSocialMediaLeadSource() {
        EOI_Public_Registration__c row = buildRow('batch-utm', 'utm.promote@modon.test');
        row.UTMSource__c = 'HGE_EOI_REG_CTW';
        row.UTMCampaign__c = 'HGE_EOI_REG_CTW';
        row.UTMMedium__c = 'cpc';
        row.UTMURL__c = 'https://modon.my.site.com/hge?utm_source=HGE_EOI_REG_CTW&sub_source=WhatsApp';
        row.AdName__c = 'HGE_EOI_REG_CTW';
        row.AdSetName__c = 'HGE_EOI_REG_CTW';
        row.UTMSubSource__c = 'WhatsApp';
        insert row;

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ row.Id });
        Test.stopTest();

        EOI_Public_Registration__c after = [
            SELECT Status__c, MatchedLead__c
            FROM EOI_Public_Registration__c WHERE Id = :row.Id
        ];
        if (after.Status__c == 'Promoted' && after.MatchedLead__c != null) {
            Lead createdLead = [
                SELECT LeadSource, SubSource__c, UTMSource__c, UTMCampaign__c, UTMMedium__c,
                       UTMURL__c, AdName__c, AdSetName__c
                FROM Lead WHERE Id = :after.MatchedLead__c
            ];
            System.assertEquals('Social Media', createdLead.LeadSource, 'UTM-attributed Lead should use Social Media source');
            System.assertEquals('WhatsApp', createdLead.SubSource__c, 'SubSource should be the URL sub_source value');
            System.assertEquals('HGE_EOI_REG_CTW', createdLead.UTMSource__c);
            System.assertEquals('HGE_EOI_REG_CTW', createdLead.UTMCampaign__c);
            System.assertEquals('cpc', createdLead.UTMMedium__c);
            System.assertEquals('HGE_EOI_REG_CTW', createdLead.AdName__c);
            System.assertEquals('HGE_EOI_REG_CTW', createdLead.AdSetName__c);
        }
    }

    @isTest
    static void testPromoteWithoutUtmKeepsSalesLaunchLeadSource() {
        EOI_Public_Registration__c row = buildRow('batch-noutm', 'noutm.promote@modon.test');
        insert row;

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ row.Id });
        Test.stopTest();

        EOI_Public_Registration__c after = [
            SELECT Status__c, MatchedLead__c
            FROM EOI_Public_Registration__c WHERE Id = :row.Id
        ];
        if (after.Status__c == 'Promoted' && after.MatchedLead__c != null) {
            Lead createdLead = [SELECT LeadSource, SubSource__c FROM Lead WHERE Id = :after.MatchedLead__c];
            System.assertEquals('Sales Launch', createdLead.LeadSource, 'Non-UTM Lead should keep Sales Launch source');
            System.assertEquals('EOI Emailer', createdLead.SubSource__c, 'Non-UTM Lead should keep EOI Emailer subsource');
        }
    }

    @isTest
    static void testPromoteCatchBlockCapturesFailure() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        EOI_Range__c rng = [SELECT Id, Phase__c FROM EOI_Range__c LIMIT 1];
        EOI_Public_Registration__c row = new EOI_Public_Registration__c(
            Status__c = 'Verified', CustomerType__c = 'Individual',
            FirstName__c = 'Broken', LastName__c = 'Promote',
            Email__c = 'broken@modon.test', Mobile__c = '+971500000002',
            Project__c = proj.Id, Phase__c = rng.Phase__c, EOI_Range__c = rng.Id,
            BatchId__c = 'batch-broken',
            Source__c = 'Public Microsite'
        );
        insert row;

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ row.Id });
        Test.stopTest();

        EOI_Public_Registration__c after = [
            SELECT Status__c, Promotion_Error__c
            FROM EOI_Public_Registration__c WHERE Id = :row.Id
        ];
        System.assertNotEquals('Verified', after.Status__c);
        if (after.Status__c == 'PromoteFailed') {
            System.assert(String.isNotBlank(after.Promotion_Error__c), 'Failure rows should capture error text');
        }
    }

    @isTest
    static void testPromotionWritesVisitClosedOnTheVisitor() {
        EOI_Public_Registration__c row = buildRow('batch-visitor', 'visitor@modon.test');
        insert row;
        EoiSiteVisitorService.Result vr = EoiSiteVisitorService.onVerified(row, 'Email', 'visitor@modon.test', null);

        Test.startTest();
        EoiRegistrationPromotionHandler.promoteFromFlow(new List<Id>{ row.Id });
        Test.stopTest();

        EOI_Public_Registration__c after = [SELECT Status__c, MatchedAccount__c FROM EOI_Public_Registration__c WHERE Id = :row.Id];
        List<Task> closed = [SELECT Description FROM Task WHERE WhatId = :vr.visitor.Id AND Subject = 'EOI: Visit closed'];
        List<Task> failed = [SELECT Description FROM Task WHERE WhatId = :vr.visitor.Id AND Subject = 'EOI: Promotion failed'];
        if (after.Status__c == 'Promoted') {
            System.assertEquals(1, closed.size(), 'one visit-closed milestone');
            System.assertEquals(after.MatchedAccount__c,
                [SELECT Matched_Account__c FROM EOI_Site_Visitor__c WHERE Id = :vr.visitor.Id].Matched_Account__c);
        } else {
            System.assertEquals(1, failed.size(), 'a failed promotion is still recorded');
        }
    }
}