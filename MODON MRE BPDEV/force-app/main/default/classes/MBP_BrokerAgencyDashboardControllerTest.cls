@isTest
private class MBP_BrokerAgencyDashboardControllerTest {

    @testSetup
    static void setupTestData() {
        // --- Broker Classification ---
        Broker_Classification__c classification = new Broker_Classification__c(Name = 'Gold');
        insert classification;

        RecordType partnerRecordType = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1
        ];

        Account acc = new Account(
            Name = 'Test Agency',
            Broker_Classification__c = classification.Id,
            Rank__c = 5,
            RecordTypeId = partnerRecordType.Id
        );
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            Broker_Type__c = 'Agent',
            AccountId = acc.Id
        );
        insert con;

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];

        Id userRoleId;
        try {
            userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
        } catch (Exception e) {
            userRoleId = null;
        }

        User u = new User(
            FirstName = 'Broker',
            LastName = 'Agent',
            Username = 'brokeragent' + DateTime.now().getTime() + '@test.com',
            Alias = 'bragent',
            Email = 'broker@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            ProfileId = p.Id,
            ContactId = con.Id,
            UserRoleId = userRoleId,
            IsActive = true
        );
        insert u;

        System.runAs(u) {
            // --- Leads ---
            // Broker_Portal_Fields_Should_be_Blank rejects a lead that carries the broker fields
            // without this source, so both leads set it rather than relying on anything upstream.
            insert new Lead(
                LastName = 'Test Lead',
                FirstName = 'Test',
                Company = 'Test Company',
                LeadSource = 'Broker Portal',
                BrokerAgent__c = con.Id,
                Status = 'Open - Not Contacted',
                IsConverted = false,
                BrokerAgentMobile__c ='8897664052',
                BrokerAgentName__c ='Upendra',
                BrokerAgency__c =acc.id,
                ProjectInterest__c = 'Nawayef Mansions'
            );

            insert new Lead(
                LastName = 'TestLeadTwo',
                FirstName = 'TestTwo',
                Company = 'Test Company',
                LeadSource = 'Broker Portal',
                BrokerAgency__c = acc.Id,
                Status = 'Open - Not Contacted',
                IsConverted = false,
                BrokerAgentMobile__c ='8897664052',
                BrokerAgentName__c ='Upendra',
                ProjectInterest__c = 'Nawayef Mansions'
            );
            
        

            // --- Opportunity ---
            Opportunity opp = new Opportunity(
                Name = 'Test Opportunity',
                  Nationality__c = 'India',
        EIDNumber__c='784-1234-1234567-1',
    UAE_Resident_Status__c = 'Resident',  
    EmiratesIDExpiryDate__c = Date.today().addYears(1) ,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(10),
                BrokerAgent__c = con.Id,
                BrokerAgency__c = acc.Id
            );
            insert opp;

            // --- Sales Orders with different values to trigger getShortStringValue formatting ---
            insert new SalesOrder__c(
                Opportunity__c = opp.Id,
                Status__c = BRConstants.UNIT_STATUS_SOLD,
                TotalAmount__c = 2500000,
                  CustomerAccount__c=opp.BrokerAgency__c,
        UAE_Resident_Status__c='Resident'
                
            );
            insert new SalesOrder__c(
                Opportunity__c = opp.Id,
                Status__c = BRConstants.UNIT_STATUS_SOLD,
                TotalAmount__c = 25000 ,
                 CustomerAccount__c=opp.BrokerAgency__c,
        UAE_Resident_Status__c='Resident'
            );
            insert new SalesOrder__c(
                Opportunity__c = opp.Id,
                Status__c = BRConstants.UNIT_STATUS_SOLD,
                TotalAmount__c = null ,
                 CustomerAccount__c=opp.BrokerAgency__c,
        UAE_Resident_Status__c='Resident'
            );
        }
    }

    @isTest
    static void testGetLoggedInUserDetail_NoLimitedAccess() {
        User u = [SELECT Id FROM User WHERE Alias = 'bragent' LIMIT 1];
        System.runAs(u) {
            Map<String, Object> result = MBP_BrokerAgencyDashboardController.getLoggedInUserDetail();
            System.assertNotEquals(null, result.get('user'));
            System.assertEquals(false, result.get('isLimitedLoginAccess'));
        }
    }

    @isTest
    static void testGetLoggedInUserDetail_WithLimitedAccess() {
        User u = [SELECT Id FROM User WHERE Alias = 'bragent' LIMIT 1];
        // Assign dummy PermissionSet
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Modon_Limited_Login_Access' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);

        System.runAs(u) {
            Map<String, Object> result = MBP_BrokerAgencyDashboardController.getLoggedInUserDetail();
            System.assertEquals(true, result.get('isLimitedLoginAccess'));
        }
    }

    @isTest
    static void testGetAgentDashboardDetails() {
        test.startTest();
        User u = [SELECT Id, ContactId FROM User WHERE Alias = 'bragent' LIMIT 1];
        System.runAs(u) {
            MBP_BrokerAgencyDashboardController.AgencyDashboardDetails details =
                MBP_BrokerAgencyDashboardController.getAgentDashboardDetails(u.ContactId);

            System.assertEquals('Gold', details.accountClassification);
            System.assertEquals(5, details.accountRank);
            System.assertEquals(4, details.kpiList.size());
        }
        test.stopTest();
    }

    @isTest
    static void testGetAgencyDashboardDetails_CurrentFY() {
        test.startTest();
        User u = [SELECT Id, AccountId FROM User WHERE Alias = 'bragent' LIMIT 1];
        System.runAs(u) {
            MBP_BrokerAgencyDashboardController.AgencyDashboardDetails details =
                MBP_BrokerAgencyDashboardController.getAgencyDashboardDetails(u.AccountId, 'Current FY', null, null);
            System.assertEquals(4, details.kpiList.size());
        }
        test.stopTest();
    }

    @isTest
    static void testGetAgencyDashboardDetails_PreviousFY() {
        test.startTest();
        User u = [SELECT Id, AccountId FROM User WHERE Alias = 'bragent' LIMIT 1];
        System.runAs(u) {
            MBP_BrokerAgencyDashboardController.AgencyDashboardDetails details =
                MBP_BrokerAgencyDashboardController.getAgencyDashboardDetails(u.AccountId, 'Previous FY', null, null);
            System.assertEquals(4, details.kpiList.size());
        }
        test.stopTest();
    }

    @isTest
    static void testGetAgencyDashboardDetails_CustomDate() {
        test.startTest();
        User u = [SELECT Id, AccountId FROM User WHERE Alias = 'bragent' LIMIT 1];
        System.runAs(u) {
            Date startDate = Date.today().addDays(-30);
            Date endDate = Date.today();
            MBP_BrokerAgencyDashboardController.AgencyDashboardDetails details =
                MBP_BrokerAgencyDashboardController.getAgencyDashboardDetails(u.AccountId, 'Custom', startDate, endDate);
            System.assertEquals(4, details.kpiList.size());
        }
        test.stopTest();
    }
}