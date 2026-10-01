/**********************************************************************************************************************
* Name               : CaseSLAControllerTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      29 Jan 2025     Initial Draft       
* 2.0           ravikumar.pasumarthi@activemindsit.com      20 Jan 2026     Changes as per Case Mgmt 2.0
******************************************************************************************************************/
@isTest
public class SystemContextClassTest {
    
    private class YourMockCallout implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"example":"response"}');
        res.setStatusCode(200);
        return res;
    }
}
    
    @isTest
    static void testGetHolidays() {
        Test.startTest();
        
        // Insert test holiday records
        Holiday testHoliday = new Holiday(Name = 'Dec 25', ActivityDate = Date.today(), IsRecurrence = false);
        insert testHoliday;
        
        // Call the method
        List<Holiday> holidays = SystemContextClass.getHolidays();
        System.assertNotEquals(0, holidays.size(), 'Holidays should not be empty');
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetBusinessHours() {
        Test.startTest();
        
        // Fetch test data
        BusinessHours businessHours = SystemContextClass.getBusinessHours();
        System.assertNotEquals(null, businessHours, 'BusinessHours should exist');
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccounts() {
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
        Test.startTest();
        
        // Fetch test data
        Map<String, Id> testData = TestDataFactory.createTestData();
        Set<Id> accountIds = new Set<Id>{testData.get('vipPersonAccount'), testData.get('vipOrganizationAccount')};
        
            // Call the method
            List<Account> accounts = SystemContextClass.getAccounts(accountIds);
        System.assertEquals(2, accounts.size(), 'Should return exactly 2 accounts');
        
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountsOfContacts() {
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
        Test.startTest();
        
        // Fetch test data
        Map<String, Id> testData = TestDataFactory.createTestData();
        Set<Id> contactIds = new Set<Id>{testData.get('vipOrganizationcontact'), testData.get('nonvipOrganizationcontact')};
            
            // Call the method
            List<Contact> contacts = SystemContextClass.getAccountsOfContacts(contactIds);
        System.assertEquals(2, contacts.size(), 'Should return exactly 2 contacts');
        
        Test.stopTest();
    }
    
@isTest
static void testGetOpenCases() {
    Test.startTest();
    List<Case> openCases = SystemContextClass.getOpenCases();// method call

    System.debug('Retrieved Open Cases: ' + openCases);
    
    Test.stopTest();
}

    //for get mastersladetailsforSR
   @testSetup
    static void setupTestData() {
        // Insert test Master_SLA__c records
        List<Master_SLA__c> slaRecords = new List<Master_SLA__c>();
        User admUser = [select id,name from user where profile.name ='System Administrator' and isactive = true limit 1];
        slaRecords.add(new Master_SLA__c(
            Name = 'Non VIP- Contact Centre-General Enquiry',
            Category__c = 'Contact Centre',
            SLA_Hrs__c = 24,
            Is_Available_For_Extension__c = true,
            Case_Origin__c = '800 Modon',
            Escalation_1_Contact__c = admUser.id,
            ObjectName__c = ServiceConstants.SOBJECT_SR,
            IsActive__c = true
        ));
        
        slaRecords.add(new Master_SLA__c(
            Name = 'Non VIP-Contact Centre-Contact Details Update',
            Category__c = 'Contact Centre',
            SLA_Hrs__c = 4,
            Is_Available_For_Extension__c = false,
            Case_Origin__c = '800 Modon',
            Escalation_1_Contact__c = admUser.id,
            ObjectName__c = ServiceConstants.SOBJECT_SR,
            IsActive__c = true
        ));

        // Inactive SLA (should not be returned)
        slaRecords.add(new Master_SLA__c(
            Name = 'Non VIP- Post Sales-ADM Fee Refund',
            Category__c = 'Contact Centre',
            SLA_Hrs__c = 2,
            Is_Available_For_Extension__c = true,
            Case_Origin__c = '800 Modon',
            Escalation_1_Contact__c = admUser.id,
            ObjectName__c = ServiceConstants.SOBJECT_SR,
            IsActive__c = false
        ));
        insert slaRecords;
    }

    @isTest
    static void testGetMasterSLADetailsForSR() {
        Test.startTest();        
        // Call the method under test
        List<Master_SLA__c> result = SystemContextClass.getMasterSLADetailsForSR();        
        Test.stopTest();
    }
    
     @isTest
    static void testGetAccountsByContactIds() {
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
        Map<String, Id> testData = TestDataFactory.createTestData();
    
        Set<Id> contactIdSet = new Set<Id>();
        contactIdSet.add(testData.get('vipOrganizationcontact'));
        contactIdSet.add(testData.get('nonvipOrganizationcontact'));

        Test.startTest();
        List<Account> accounts = SystemContextClass.getAccountsByContactIds(contactIdSet);
        Test.stopTest();
   
        System.assertNotEquals(null, accounts, 'Account list should not be null');
        System.assert(accounts.size() > 0, 'At least one account should be returned');
        
        for (Account acc : accounts) {
            System.assert(contactIdSet.contains(acc.Contacts[0].Id), 'Returned account should be linked to provided contacts');
        }
    }    
    
     @isTest
    static void testGetAccountsByEmirateIds() {
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
        Map<String, Id> testData = TestDataFactory.createTestData();
        
        Id testAccountId = testData.get('vipOrganizationAccount');
        Id testContactId = testData.get('vipOrganizationcontact');

        System.assertNotEquals(null, testAccountId, 'Test Account ID should not be null');
        System.assertNotEquals(null, testContactId, 'Test Contact ID should not be null');

        Contact testContact = [SELECT Id, EIDNumber__c FROM Contact WHERE Id = :testContactId LIMIT 1];
        System.assertNotEquals(null, testContact.EIDNumber__c, 'Test Contact should have EIDNumber__c set');

        Set<String> emiratesIdSet = new Set<String>{ testContact.EIDNumber__c };

        Test.startTest();
        List<Account> accounts = SystemContextClass.getAccountsByEmirateIds(emiratesIdSet);
        Test.stopTest();

        System.assertNotEquals(null, accounts, 'Account list should not be null');
        System.assert(accounts.size() > 0, 'At least one account should be returned');        
    }
        
     @isTest
    static void testGetAccountsByPhone() {
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
       
        Map<String, Id> testData = TestDataFactory.createTestData();

        Set<String> phoneSet = new Set<String>();
        phoneSet.add('+919876543210');  // From the Account 'vipPersonAccount'
        phoneSet.add('+919876543201');  // From the Account 'nonvipPersonAccount'
        
        // Step 3: Call the method under test
        List<Account> result = SystemContextClass.getAccountsByPhone(phoneSet);        
    }

    
    @isTest
    static void testGetAccountsByEmail() {
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
      
        Map<String, Id> testData = TestDataFactory.createTestData();
        
        Set<String> emailSet = new Set<String>();
        emailSet.add('Test.Contact1@gmail.com');  // From Contact 'vipOrganizationcontact'
        emailSet.add('Test.Contact2@gmail.com');  // From Contact 'nonvipOrganizationcontact'
        
        List<Account> result = SystemContextClass.getAccountsByEmail(emailSet);
    }
    
    @isTest
    static void testgetRoundRobinMembers() {        
        Map<Id,RoundRobinAssignmentMatrix__c> result = SystemContextClass.getRoundRobinMembers();
    }
    
    @isTest
	static void testGetCaseSLAs() {
    Test.setMock(HttpCalloutMock.class, new YourMockCallout());
    User admUser = [select id,name from user where profile.name ='System Administrator' and isactive = true limit 1];
    Map<String, Id> testData = TestDataFactory.createTestData();
    Id testCase1 = testData.get('testCase1');
    Id testCase2 = testData.get('testCase2');
    master_SLA__c msla = [select id,name,Escalation_1_Contact__c from master_Sla__c where Escalation_1_Contact__c != null limit 1];
    // Step 2: Create CaseSLA__c records for the test Cases
    CaseSLA__c caseSla1 = new CaseSLA__c(
        CaseId__c = testCase1,
        Master_SLA__c = msla.id,
        Status__c = 'OnTrack'
    );
    insert caseSla1;
    
    CaseSLA__c caseSla2 = new CaseSLA__c(
        CaseId__c = testCase2,
        Master_SLA__c = msla.id,
        Status__c = 'Breached'
    );
    insert caseSla2;
    
    Set<Id> caseIdSet = new Set<Id>();
    caseIdSet.add(testCase1);
    caseIdSet.add(testCase2);
    
    // Step 4: Call the method under test
    Test.startTest();
    List<CaseSLA__c> result = SystemContextClass.getCaseSLAs(caseIdSet);
    Test.stopTest();
    
    // Step 5: Validate the result
    System.assertNotEquals(null, result, 'The result should not be null');
    System.assertEquals(True, result.size()>0 , 'There should be 1 CaseSLA__c records returned');
    
    // Verify the returned CaseSLA__c records match the expected CaseId and Status
    System.assertEquals(testCase1, result[0].CaseId__c, 'The first CaseSLA__c should be for the first Case');
    System.assertEquals('OnTrack', result[0].Status__c, 'The status of the first CaseSLA__c should be "OnTrack"');
    
    System.assertEquals(testCase2, result[1].CaseId__c, 'The second CaseSLA__c should be for the second Case');
    System.assertEquals('Breached', result[1].Status__c, 'The status of the second CaseSLA__c should be "Breached"');
}
    
    @isTest
	static void testGetOpenTasksForCases() {
    Test.setMock(HttpCalloutMock.class, new YourMockCallout());
    Test.startTest();

    // Step 1: Generate Test Data using TestDataFactory
    Map<String, Id> testData = TestDataFactory.createTestData();
    Id caseId1 = testData.get('testCase1');
    Id caseId2 = testData.get('testCase2');

    Task openTask1 = new Task(
        WhatId = caseId1,
        Subject = 'Open Task 1',
        Status = 'Open'      
    );

    Task openTask2 = new Task(
        WhatId = caseId2,
        Subject = 'Open Task 2',
        Status = 'Not Started'       
    );

    //insert new List<Task>{ openTask1, openTask2, closedTask };
insert new List<Task>{ openTask1, openTask2 };
    // Step 3: Call the method under test
    Set<Id> caseIdSet = new Set<Id>{ caseId1, caseId2 };
    List<Task> result = SystemContextClass.getOpenTasksForCases(caseIdSet);
  List<ProcessInstance> result1 = SystemContextClass.getPendingApprovalRequests(caseIdSet);
    Test.stopTest();

    System.assertEquals(2, result.size(), 'Expected 2 open tasks.');
    Set<Id> taskIds = new Set<Id>{ result[0].Id, result[1].Id };
    System.assert(taskIds.contains(openTask1.Id), 'Expected openTask1 in results.');
    System.assert(taskIds.contains(openTask2.Id), 'Expected openTask2 in results.');
}

    @isTest
    static void testRemainingQueryHelpers() {
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
        Map<String, Id> testData = TestDataFactory.createTestData();

        Test.startTest();
        Map<String, BusinessHours> hoursByName = SystemContextClass.getActiveBusinessHours();
        Map<Id, BusinessHours> hoursById = SystemContextClass.getActiveBusinessHoursBasedOnId();
        List<Master_SLA__c> caseSlas = SystemContextClass.getMasterSLADetailsForCase();
        User loggedIn = SystemContextClass.getLoggedInUserDetails();
        List<Group> queues = SystemContextClass.getQueueNames();
        List<User> users = SystemContextClass.getUserDetails(new Set<Id>{ UserInfo.getUserId() });
        List<Unit__c> unitsById = SystemContextClass.getAccountsByUnitIds(new Set<Id>{ testData.get('Unit') });
        List<Account> accountsById = SystemContextClass.getAccountsByAccountIds(
            new Set<Id>{ testData.get('vipOrganizationAccount'), testData.get('vipPersonAccount') }
        );
        List<Opportunity> opps = SystemContextClass.getOpportunitiesWithUnits(
            new Set<Id>{ testData.get('vipOrganizationAccount') }
        );
        List<Unit__c> unitAccounts = SystemContextClass.getAccountOfUnits(new Set<Id>{ testData.get('Unit') });
        List<GroupMember> currentGroups = SystemContextClass.getCurrentUserGroups();
        User byName = SystemContextClass.getUserDetailsBasedOnUserName(UserInfo.getUserName());
        SalesOrder__c latestSo = SystemContextClass.getLatestSalesOrderOfUnit(String.valueOf(testData.get('Unit')));
        List<GroupMember> userGroups = SystemContextClass.getUserGroups(UserInfo.getUserId());
        String accountFromSo = SystemContextClass.getAccountFromSO(testData.get('SalesOrder'));
        Map<Id, Id> latestByUnit = SystemContextClass.getLatestSalesOrdersByUnitIds(new Set<Id>{ testData.get('Unit') });
        Map<Id, Id> soAccounts = SystemContextClass.getAccountsFromSalesOrders(new Set<Id>{ testData.get('SalesOrder') });
        List<GroupMember> groupsByUsers = SystemContextClass.getUserGroupsByUserIds(new Set<Id>{ UserInfo.getUserId() });
        User foundUser = SystemContextClass.findActiveUserByUserName(UserInfo.getUserName());
        List<Task> tasksByWhat = SystemContextClass.getTasksByWhatIds(new Set<Id>());
        SystemContextClass.getLatestSalesOrdersByUnitIds(new Set<Id>());
        SystemContextClass.getAccountsFromSalesOrders(new Set<Id>());
        SystemContextClass.getUserGroupsByUserIds(new Set<Id>());
        SystemContextClass.findActiveUserByUserName(null);
        Test.stopTest();

        System.assertNotEquals(null, hoursByName);
        System.assertNotEquals(null, hoursById);
        System.assertNotEquals(null, caseSlas);
        System.assertEquals(UserInfo.getUserId(), loggedIn.Id);
        System.assertNotEquals(null, queues);
        System.assertEquals(1, users.size());
        System.assertNotEquals(null, unitsById);
        System.assert(accountsById.size() > 0);
        System.assertNotEquals(null, opps);
        System.assertEquals(1, unitAccounts.size());
        System.assertNotEquals(null, currentGroups);
        System.assertEquals(UserInfo.getUserId(), byName.Id);
        System.assertNotEquals(null, latestSo);
        System.assertNotEquals(null, userGroups);
        System.assertEquals(String.valueOf(testData.get('vipOrganizationAccount')), accountFromSo);
        System.assertEquals(true, latestByUnit.containsKey(testData.get('Unit')));
        System.assertEquals(true, soAccounts.containsKey(testData.get('SalesOrder')));
        System.assertNotEquals(null, groupsByUsers);
        System.assertEquals(UserInfo.getUserId(), foundUser.Id);
        System.assertEquals(0, tasksByWhat.size());
    }
}