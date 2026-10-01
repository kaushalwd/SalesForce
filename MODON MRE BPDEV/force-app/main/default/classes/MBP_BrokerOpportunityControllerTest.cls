@isTest
private class MBP_BrokerOpportunityControllerTest {

    @testSetup
    static void setupTestData() {
        RecordType partnerRecordType = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1
        ];

        Account agency = new Account(Name = 'Test Agency', RecordTypeId = partnerRecordType.Id);
        insert agency;

        Contact agentContact = new Contact(
            FirstName = 'Agent',
            LastName = 'One',
            Email = 'agent@example.com',
            Broker_Type__c = 'Agent',
            AccountId = agency.Id
        );
        insert agentContact;

        Contact ownerContact = new Contact(
            FirstName = 'Owner',
            LastName = 'One',
            Email = 'owner@example.com',
            Broker_Type__c = 'Owner',
            AccountId = agency.Id
        );
        insert ownerContact;

        Contact adminContact = new Contact(
            FirstName = 'Admin',
            LastName = 'One',
            Email = 'admin@example.com',
            Broker_Type__c = 'Agency Admin',
            AccountId = agency.Id
        );
        insert adminContact;

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];

        Id userRoleId;
        try {
            userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
        } catch (Exception e) {
            userRoleId = null;
        }

        insert new List<User>{
            new User(
                FirstName = 'AgentUser',
                LastName = 'One',
                Email = 'agentuser@example.com',
                Username = 'agentuser' + DateTime.now().getTime() + '@test.com',
                Alias = 'agusr',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id,
                ContactId = agentContact.Id,
                UserRoleId = userRoleId,
                IsActive = true
            ),
            new User(
                FirstName = 'OwnerUser',
                LastName = 'One',
                Email = 'owneruser@example.com',
                Username = 'owneruser' + DateTime.now().getTime() + '@test.com',
                Alias = 'ownusr',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id,
                ContactId = ownerContact.Id,
                UserRoleId = userRoleId,
                IsActive = true
            ),
            new User(
                FirstName = 'AdminUser',
                LastName = 'One',
                Email = 'adminuser@example.com',
                Username = 'adminuser' + DateTime.now().getTime() + '@test.com',
                Alias = 'admusr',
                TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id,
                ContactId = adminContact.Id,
                UserRoleId = userRoleId,
                IsActive = true
            )
        };

        List<Contact> contacts = [
            SELECT Id, Broker_Type__c, AccountId
            FROM Contact 
            WHERE Email LIKE '%@example.com'
        ];

        List<Opportunity> opps = new List<Opportunity>();

        for (Contact c : contacts) {
            Opportunity opp = new Opportunity(
                Name = 'Test Opp for ' + c.Broker_Type__c,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                BrokerAgency__c = c.AccountId,
                BrokerAgent__c = c.Id,
                Nationality__c = 'India',
                UAE_Resident_Status__c = 'Resident',
                EmiratesIDExpiryDate__c = System.today()+1,
                ProjectInterest__c = 'Muheira',
                EIDNumber__c='784-7867-7837388-1'
            );
            opps.add(opp);
        }

        insert opps;
    }
   @isTest
    static void testGetUserInfo() {
        User owner = [SELECT Id FROM User WHERE Email = 'owneruser@example.com' LIMIT 1];
        System.runAs(owner) {
            User info = MBP_BrokerOpportunityController.getUserInfo();
        }
    }
    @isTest
static void testAgencyAdminBranch() {
    User admin = [SELECT Id FROM User WHERE Email = 'adminuser@example.com' LIMIT 1];
    
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Agency' LIMIT 1];

        Date startDate = Date.today().addDays(-10);
        Date endDate   = Date.today().addDays(10);

        List<Map<String, Object>> results = MBP_BrokerOpportunityController.getOpportunitiesForAgency(
            acc.Id, startDate, endDate
        );
     List<Map<String, Object>> results1 = MBP_BrokerOpportunityController.getOpportunitiesForAgency(
            acc.Id, null, null
        );
        System.assertNotEquals(null, results);
    
}

@isTest
static void testOwnerBranch() {
    User owner = [SELECT Id FROM User WHERE Email = 'owneruser@example.com' LIMIT 1];

        Account acc = [SELECT Id FROM Account LIMIT 1];

        
        Date startDate = Date.today().addDays(-30);
        Date endDate   = Date.today();

        List<Map<String, Object>> results = MBP_BrokerOpportunityController.getOpportunitiesForAgency(
            acc.Id, startDate, endDate
        );
    List<Map<String, Object>> results1 = MBP_BrokerOpportunityController.getOpportunitiesForAgency(
            acc.Id, null, null
        );
        System.assertNotEquals(null, results);
    
}

@isTest
static void testAgentBranch() {
    User agent = [SELECT Id FROM User WHERE Email = 'agentuser@example.com' LIMIT 1];
   
        Account acc = [SELECT Id FROM Account LIMIT 1];

        
        Date startDate = Date.today().addMonths(-1);
        Date endDate   = Date.today().addMonths(1);

        List<Map<String, Object>> results = MBP_BrokerOpportunityController.getOpportunitiesForAgency(
            acc.Id, startDate, endDate
        );
    List<Map<String, Object>> results1 = MBP_BrokerOpportunityController.getOpportunitiesForAgency(
            acc.Id, null, null
        );
        System.assertNotEquals(null, results);
    
}


    @isTest
    static void testGetSalesOrdersForOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        List<SalesOrder__c> orders = MBP_BrokerOpportunityController.getSalesOrdersForOpportunity(opp.Id);
    }


 
}