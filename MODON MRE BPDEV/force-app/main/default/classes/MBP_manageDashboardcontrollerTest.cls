@IsTest
private class MBP_manageDashboardcontrollerTest {

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
    Contact ownerContact = new Contact(
        FirstName = 'Owner',
        LastName = 'One',
        Email = 'owner@example.com',
        Broker_Type__c = 'Owner',
        AccountId = agency.Id
    );
    Contact adminContact = new Contact(
        FirstName = 'Admin',
        LastName = 'One',
        Email = 'admin@example.com',
        Broker_Type__c = 'Agency Admin',
        AccountId = agency.Id
    );
    insert new List<Contact>{agentContact, ownerContact, adminContact};

    Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];

    User agentUser = new User(
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
        IsActive = true
    );
    User ownerUser = new User(
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
        IsActive = true
    );
    User adminUser = new User(
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
        IsActive = true
    );
    insert new List<User>{agentUser, ownerUser, adminUser};

    Project__c project = new Project__c(Name = 'Test Project');
    insert project;

    Phase__c phase = new Phase__c(Name = 'Test Phase', Project__c = project.Id);
    insert phase;

    Unit__c unit1 = new Unit__c(
        Name = 'Unit 101',
        Phase__c = phase.Id,
        Number_of_Bedrooms__c = '2',
        Status__c = 'Sold',
        UnitClassification__c = 'Villa',
        PlotNo__c = 'test1'
    );

    Unit__c unit2 = new Unit__c(
        Name = 'Unit 102',
        Status__c = 'Sold',
        Number_of_Bedrooms__c = '3',
        Phase__c = phase.Id,
        UnitClassification__c = 'Townhouse',
        Unit_Sold_Date__c = Date.today(),
        PlotNo__c = 'test2'
    );

    insert new List<Unit__c>{unit1, unit2};

    Opportunity opp1 = new Opportunity(
        Name = 'Test Opp for Agent',
        StageName = 'Unit Selection', 
        CloseDate = Date.today().addDays(30),
        BrokerAgency__c = agency.Id,
        BrokerAgent__c = agentContact.Id,
        Nationality__c = 'India',
        EIDNumber__c = '784-1234-1234567-1',
        UAE_Resident_Status__c = 'Resident',
        EmiratesIDExpiryDate__c = Date.today().addYears(1)
    );

    Opportunity opp2 = new Opportunity(
        Name = 'Test Opp for Owner',
        StageName = 'Unit Selection', 
        CloseDate = Date.today().addDays(30),
        BrokerAgency__c = agency.Id,
        BrokerAgent__c = ownerContact.Id,
        Nationality__c = 'India',
        EIDNumber__c = '784-1234-1234567-1',
        PassportNumber__c = '8798399',
        UAE_Resident_Status__c = 'Non-Resident',
        PassportExpiryDate__c = Date.today().addDays(30),
        PassportIssueDate__c = Date.today().addDays(-30)
    );

    insert new List<Opportunity>{opp1, opp2};

    SalesOrder__c so1 = new SalesOrder__c(
        Unit__c = unit1.Id,
        Opportunity__c = opp1.Id,
        Status__c = 'Completed',
        CustomerAccount__c = agency.Id,
        UAE_Resident_Status__c = 'Resident'
    );
    SalesOrder__c so2 = new SalesOrder__c(
        Unit__c = unit2.Id,
        Opportunity__c = opp2.Id,
        Status__c = 'Completed',
        CustomerAccount__c = agency.Id,
        UAE_Resident_Status__c = 'Non-Resident'
    );
    insert new List<SalesOrder__c>{so1, so2};
  }

  @IsTest
  static void testAllDashboardMethods() {
    User admin = [SELECT Id FROM User WHERE Email = 'adminuser@example.com' LIMIT 1];

    Date startDt = Date.today().toStartOfMonth();
    Date endDt = Date.today();

    Test.startTest();
    MBP_manageDashboardcontroller.getUnitsByNationalityData('Current FY', null, null);
    MBP_manageDashboardcontroller.getSalesByNationality('Current FY', null, null);
    MBP_manageDashboardcontroller.getProjectUnitClassificationBedroomData('Current FY', null, null);
    MBP_manageDashboardcontroller.getGroupedProjectSalesData('Current FY', null, null);
    MBP_manageDashboardcontroller.getMonthlySalesByProject('Current FY', null, null);
    MBP_manageDashboardcontroller.getSalesByResidence('Current FY', null, null);
    MBP_manageDashboardcontroller.getSalesByBedrooms('Current FY', null, null);
    MBP_manageDashboardcontroller.getTotalSalesAmount('Current FY', null, null);
    MBP_manageDashboardcontroller.getUnitsByNationalityData('Custom', startDt, endDt);
    MBP_manageDashboardcontroller.getSalesByNationality('Last FY', null, null);
    try {
        MBP_manageDashboardcontroller.getCommissionSummary(null, null, 'Current FY', null, null);
    } catch (Exception e) {}
    Test.stopTest();

    System.runAs(admin) {
        MBP_manageDashboardcontroller.getGroupedProjectSalesData('Current FY', null, null);
    }
  }
}