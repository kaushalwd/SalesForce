@isTest
public class MBP_aiContextServiceTest {

    @testSetup
    static void setupTestData() {
        RecordType brokerRt = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency'
            LIMIT 1
        ];

        Account agency = new Account(
            Name = 'AI Context Agency',
            RecordTypeId = brokerRt.Id
        );
        insert agency;

        Contact agentContact = new Contact(
            FirstName = 'Agent',
            LastName = 'Context',
            Email = 'agent.context@test.com',
            MobilePhone = '971500000002',
            Broker_Type__c = 'Agent',
            Agent_Status__c = 'Active',
            Nationality__c = 'United Arab Emirates',
            EIDNumber__c = '784-0000-0000000-1',
            PassportNumber__c = 'P1234567',
            AccountId = agency.Id
        );
        Contact ownerContact = new Contact(
            FirstName = 'Owner',
            LastName = 'Context',
            Email = 'owner.context@test.com',
            MobilePhone = '971500000003',
            Broker_Type__c = 'Owner',
            Agent_Status__c = 'Active',
            Nationality__c = 'India',
            AccountId = agency.Id
        );
        Contact invalidContact = new Contact(
            FirstName = 'Invalid',
            LastName = 'Broker',
            AccountId = agency.Id
        );
        insert new List<Contact>{ agentContact, ownerContact, invalidContact };

        Profile partnerProfile = [
            SELECT Id FROM Profile
            WHERE Name = 'Modon - Partner Community Login User'
            LIMIT 1
        ];

        User agentUser = new User(
            FirstName = 'Agent',
            LastName = 'User',
            Email = 'agent.context.user@test.com',
            Username = 'agentctx' + DateTime.now().getTime() + '@test.com',
            Alias = 'agctx',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfile.Id,
            ContactId = agentContact.Id,
            IsActive = true
        );
        User ownerUser = new User(
            FirstName = 'Owner',
            LastName = 'User',
            Email = 'owner.context.user@test.com',
            Username = 'ownerctx' + DateTime.now().getTime() + '@test.com',
            Alias = 'owctx',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfile.Id,
            ContactId = ownerContact.Id,
            IsActive = true
        );
        User invalidUser = new User(
            FirstName = 'Invalid',
            LastName = 'User',
            Email = 'invalid.context.user@test.com',
            Username = 'invalidctx' + DateTime.now().getTime() + '@test.com',
            Alias = 'inctx',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = partnerProfile.Id,
            ContactId = invalidContact.Id,
            IsActive = true
        );
        insert new List<User>{ agentUser, ownerUser, invalidUser };

        Project__c project = new Project__c(Name = 'AI Context Project');
        insert project;

        Phase__c phase = new Phase__c(Name = 'Phase A', Project__c = project.Id);
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit AI-101',
            Phase__c = phase.Id,
            Status__c = 'Sold',
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Apartment',
            PlotNo__c = 'P1'
        );
        insert unit;

        System.runAs(agentUser) {
            insert new Lead(
                FirstName = 'Lead',
                LastName = 'One',
                Company = 'Lead Co',
                Email = 'lead.one@test.com',
                MobilePhone = '+971500000010',
                BrokerAgency__c = agency.Id,
                BrokerAgent__c = agentContact.Id,
                BrokerAgentName__c = 'Agent Context',
                LeadSource = 'Broker Portal',
                Status = 'New',
                ProjectInterest__c = 'Nawayef Mansions ',
                UnitType__c = 'Apartment',
                NumberOfBedrooms__c = '2 BHK + M',
                PurposeofUse__c = 'Investor'
            );
        }

        Opportunity opp = new Opportunity(
            Name = 'AI Context Opp',
            StageName = 'Unit Selection',
            CloseDate = Date.today().addDays(30),
            BrokerAgency__c = agency.Id,
            BrokerAgent__c = agentContact.Id,
            ProjectInterest__c = 'Nawayef Mansions ',
            Nationality__c = 'United Arab Emirates',
            EIDNumber__c = '784-1234-1234567-1',
            UAE_Resident_Status__c = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addYears(1)
        );
        insert opp;

        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = opp.Id,
            CustomerAccount__c = agency.Id,
            Unit__c = unit.Id,
            Status__c = 'Completed',
            TotalAmount__c = 1500000,
            Totalpaidamount__c = 500000,
            UAE_Resident_Status__c = 'Resident'
        );
        insert so;

        insert new Commission_Line__c(
            Sales_Order__c = so.Id,
            Broker_Agency__c = agency.Id,
            Broker_Agent__c = agentContact.Id,
            Commission_Line_Type__c = 'External',
            Commission_Amount__c = 25000,
            Invoice_Date__c = Date.today(),
            Booking_Date__c = Date.today()
        );
    }

    @isTest
    static void testClassify() {
        System.assertEquals('COMMISSION', MBP_aiContextService.classify('What is my commission invoice payout?'));
        System.assertEquals('SALESORDER', MBP_aiContextService.classify('Show me units sold in sales order'));
        System.assertEquals('OPPORTUNITY', MBP_aiContextService.classify('How many deals are in my opportunity pipeline?'));
        System.assertEquals('AGENTS', MBP_aiContextService.classify('List all broker agents in my team'));
        System.assertEquals('AGENTS', MBP_aiContextService.classify('Show my team brokers'));
        System.assertEquals('AGENCY', MBP_aiContextService.classify('What is my agency vat number and trade license?'));
        System.assertEquals('LEADS', MBP_aiContextService.classify('Show me new lead enquiries'));
        System.assertEquals('GENERAL', MBP_aiContextService.classify('Help me with general information'));
        System.assertEquals('GENERAL', MBP_aiContextService.classify(null));
        System.assertEquals('GENERAL', MBP_aiContextService.classify(''));
    }

    @isTest
    static void testBuildContextsRouting() {
        Test.startTest();
        System.assertEquals(null, MBP_aiContextService.buildContext('GENERAL'));
        System.assertNotEquals(null, MBP_aiContextService.buildContext('LEADS'));
        System.assertNotEquals(null, MBP_aiContextService.buildContext('OPPORTUNITY'));
        System.assertNotEquals(null, MBP_aiContextService.buildContext('SALESORDER'));
        System.assertNotEquals(null, MBP_aiContextService.buildContext('COMMISSION'));
        System.assertNotEquals(null, MBP_aiContextService.buildContext('AGENCY'));
        System.assertNotEquals(null, MBP_aiContextService.buildContext('AGENTS'));
        Test.stopTest();
    }

    @isTest
    static void testBuildLeadContextAsAgent() {
        User agentUser = [SELECT Id FROM User WHERE Email = 'agent.context.user@test.com' LIMIT 1];

        Test.startTest();
        MBP_aiContextService.GroundedContext ctx;
        System.runAs(agentUser) {
            ctx = MBP_aiContextService.buildLeadContext();
        }
        Test.stopTest();

        System.assertNotEquals(null, ctx);
        System.assertEquals(true, ctx.hasData);
        System.assert(ctx.dataText.contains('TOTAL_LEADS='));
        System.assert(ctx.dataText.contains('Lead 1'));
    }

    @isTest
    static void testBuildLeadContextAsOwner() {
        User ownerUser = [SELECT Id FROM User WHERE Email = 'owner.context.user@test.com' LIMIT 1];

        Test.startTest();
        MBP_aiContextService.GroundedContext ctx;
        System.runAs(ownerUser) {
            ctx = MBP_aiContextService.buildLeadContext();
        }
        Test.stopTest();

        System.assertNotEquals(null, ctx);
        System.assertEquals(true, ctx.hasData);
    }

    @isTest
    static void testBuildDomainContextsAsOwner() {
        User ownerUser = [SELECT Id FROM User WHERE Email = 'owner.context.user@test.com' LIMIT 1];

        Test.startTest();
        System.runAs(ownerUser) {
            MBP_aiContextService.GroundedContext oppCtx = MBP_aiContextService.buildOpportunityContext();
            System.assertEquals(true, oppCtx.hasData);
            System.assert(oppCtx.dataText.contains('TOTAL_OPPORTUNITIES='));

            MBP_aiContextService.GroundedContext soCtx = MBP_aiContextService.buildSalesOrderContext();
            System.assertNotEquals(null, soCtx);

            MBP_aiContextService.GroundedContext comCtx = MBP_aiContextService.buildCommissionContext();
            System.assertEquals(true, comCtx.hasData);
            System.assert(comCtx.dataText.contains('COMMISSION_SUMMARY'));

            MBP_aiContextService.GroundedContext agencyCtx = MBP_aiContextService.buildAgencyContext();
            System.assertEquals(true, agencyCtx.hasData);
            System.assert(agencyCtx.dataText.contains('AGENCY PROFILE'));

            MBP_aiContextService.GroundedContext agentsCtx = MBP_aiContextService.buildAgentsContext();
            System.assertEquals(true, agentsCtx.hasData);
            System.assert(agentsCtx.dataText.contains('TOTAL_AGENTS='));
        }
        Test.stopTest();
    }

    @isTest
    static void testInvalidBrokerTypeReturnsEmptyContext() {
        User invalidUser = [SELECT Id FROM User WHERE Email = 'invalid.context.user@test.com' LIMIT 1];

        Test.startTest();
        MBP_aiContextService.GroundedContext ctx;
        System.runAs(invalidUser) {
            ctx = MBP_aiContextService.buildLeadContext();
        }
        Test.stopTest();

        System.assertEquals(false, ctx.hasData);
    }

    @isTest
    static void testAdminUserWithoutContactReturnsEmptyContext() {
        Test.startTest();
        MBP_aiContextService.GroundedContext ctx = MBP_aiContextService.buildLeadContext();
        Test.stopTest();

        System.assertEquals(false, ctx.hasData);
    }

    @isTest
    static void testRedactAndUnredact() {
        Map<String, String> tokenMap = new Map<String, String>{
            '@@NM1@@' => 'John Doe',
            '@@EM1@@' => 'john@test.com'
        };

        Test.startTest();
        String redacted = MBP_aiContextService.redact('Contact John Doe at john@test.com', tokenMap);
        String unredacted = MBP_aiContextService.unredact('Contact @@NM1@@ at @@EM1@@', tokenMap);
        String blankRedact = MBP_aiContextService.redact(null, tokenMap);
        String blankUnredact = MBP_aiContextService.unredact('', null);
        Test.stopTest();

        System.assert(redacted.contains('@@NM1@@'));
        System.assert(redacted.contains('@@EM1@@'));
        System.assertEquals('Contact John Doe at john@test.com', unredacted);
        System.assertEquals(null, blankRedact);
        System.assertEquals('', blankUnredact);
    }

    @isTest
    static void testGroundedContextConstructor() {
        MBP_aiContextService.GroundedContext ctx = new MBP_aiContextService.GroundedContext();
        System.assertEquals('', ctx.dataText);
        System.assertEquals(false, ctx.hasData);
        System.assertNotEquals(null, ctx.tokenMap);
    }
}