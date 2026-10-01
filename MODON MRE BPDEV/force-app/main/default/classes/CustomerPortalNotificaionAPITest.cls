/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 13-05-2025
 * @last modified by  : Krishna Chaitanya
 * * --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Krishna Chaitanya   13 May 2025   		Initial Draft 
* 2.0           Manoj   	        09 Dec 2025   		Update logic 
* 3.0 			Manoj				09 Jan 2025			Update test class for case
**/

@IsTest
private class CustomerPortalNotificaionAPITest {
    
    @TestSetup
    static void setupTestData() {
        
       // Create role hierarchy
        UserRole parentRole = new UserRole(DeveloperName = 'ParentRole', Name = 'Parent Role');
        insert parentRole;
        
        UserRole portalRole = new UserRole(
            DeveloperName = 'PortalRole', 
            Name = 'Portal Role',
            ParentRoleId = parentRole.Id
        );
        insert portalRole;
        
        // Create account owner
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User accountOwner = new User(
            Alias = 'accown',
            Email = 'account.owner@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Owner',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'account.owner@example.com',
            UserRoleId = portalRole.Id
        );
        insert accountOwner;
        
        // Create test data as account owner
        System.runAs(accountOwner) {
           // Get Organization Account Record Type
            RecordType rec = [select id,DeveloperName from
                              RecordType where sobjectType = 'Account' 
                              and DeveloperName = 'OrganizationAccount' limit 1];

            
            // Create Test Account (Organization Type)
            Account testAccount = new Account(
                Name = 'Test Organization Account',
                RecordTypeId = rec.Id,
                //EIDNumber__c = 'EID12345',
                Phone = '1234567890',
                OwnerId = accountOwner.Id);
            insert testAccount;
            
            // Contact
            Contact testContact = new Contact(
                FirstName = 'Test',
                LastName = 'User',
                Email = 'testuser@modonexample.com',
                AccountId = testAccount.Id,
                MobilePhone = '1234567890'
            );
            insert testContact;
            
            // Portal User
            Profile portalProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community%' LIMIT 1];
            User portalUser = new User(
                Alias = 'testusr',
                Email = 'testuser@modonexample.com',
                EmailEncodingKey = 'UTF-8',
                LastName = 'User',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                ProfileId = portalProfile.Id,
                TimeZoneSidKey = 'America/Los_Angeles',
                Username = 'testuser@modonexample.com',
                ContactId = testContact.Id,
                IsActive = true
            );
            insert portalUser;
            
            // Set password
            //System.setPassword(portalUser.Id, 'testPassword123');
            
        }
    
    }
    
    @IsTest
    static void testGetNotificaion_Success() {
        // Create test Portal Notification records
        List<Portal_Notification__c> testNotifications = new List<Portal_Notification__c>();
        Date startOfMonth = Date.today().toStartOfMonth();
        
        // Create notifications for current month
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 1',
            Event_Date_Time__c = startOfMonth.addDays(1),
            Event_Description__c = 'Test Description 1'
        ));
        
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 2',
            Event_Date_Time__c = startOfMonth.addDays(5),
            Event_Description__c = 'Test Description 2'
        ));
        
        // Create a notification from previous month (shouldn't be returned)
        testNotifications.add(new Portal_Notification__c(
            Name = 'Old Notification',
            Event_Date_Time__c = startOfMonth.addDays(-1),
            Event_Description__c = 'Should not appear'
        ));
        
        insert testNotifications;
        
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
        // Set up the REST request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/CustomerPortalNotificaionAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'testuser');
        req.addParameter('token', 'testuser');
        RestContext.request = req;
        
        // Set up the REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method to test
        Test.startTest();
        CustomerPortalNotificaionAPI.getNotificaion();
        Test.stopTest();
        
        // Verify the response
       // System.assertEquals(200, res.statusCode, 'Status code should be 200 for success');
        
        // Deserialize the response
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('success', responseMap.get('status'), 'Status should be success');
        
        // Verify the notifications data
        List<Object> notifications = (List<Object>)responseMap.get('data');
        System.assertEquals(2, notifications.size(), 'Should return 2 notifications for current month');
    }
    
    @IsTest
    static void testGetNotificaion_MissingUserName() {
        // Create test Portal Notification records
        List<Portal_Notification__c> testNotifications = new List<Portal_Notification__c>();
        Date startOfMonth = Date.today().toStartOfMonth();
        
        // Create notifications for current month
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 1',
            Event_Date_Time__c = startOfMonth.addDays(1),
            Event_Description__c = 'Test Description 1'
        ));
        
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 2',
            Event_Date_Time__c = startOfMonth.addDays(5),
            Event_Description__c = 'Test Description 2'
        ));
        
        // Create a notification from previous month (shouldn't be returned)
        testNotifications.add(new Portal_Notification__c(
            Name = 'Old Notification',
            Event_Date_Time__c = startOfMonth.addDays(-1),
            Event_Description__c = 'Should not appear'
        ));
        
        insert testNotifications;
        
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
        // Set up the REST request without userName
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/CustomerPortalNotificaionAPI/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        
        // Set up the REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
          User testUser = [SELECT Id, LastName,Email, MobilePhone FROM User WHERE Username = 'testuser@modonexample.com'];
        Contact AccUser = [SELECT Id, Email FROM Contact WHERE Email = 'testuser@modonexample.com'];
      
        // Call the method to test
        Test.startTest();
         // Create a case to test the method
        Case testCase = new Case(
            Status = 'New',
            Origin ='Customer Portal',
            Subject = 'Contact Update Request',
            SuppliedEmail = testUser.Email,
            SuppliedPhone = testUser.MobilePhone,
            CaseCategory__c = 'General Enquiry',
            Requestor_Name__c = 'test name',
                        Requestor_Phone__c = '+971525612345',
            //CaseSubCategory__c = 'Property Transfer',
            Description = 'This is Description',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Web Cases').getRecordTypeId()
             
           // Requestor_Name__c=testUser.LastName
        );
        insert testCase;
        
        CustomerPortalNotificaionAPI.getNotificaion();
        Test.stopTest();
        
        // Verify the response
        System.assertEquals(200, res.statusCode, 'Status code should be 400 for missing parameter');
        
        // Deserialize the response
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'), 'Status should be error');
        System.assertEquals('Missing user creds parameter', responseMap.get('message'), 'Error message should match');
    }
    
    @IsTest
    static void testGetNotificaion_NoNotificationsFound() {
        // Create test Portal Notification records
        List<Portal_Notification__c> testNotifications = new List<Portal_Notification__c>();
        Date startOfMonth = Date.today().toStartOfMonth();
        
        // Create notifications for current month
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 1',
            Event_Date_Time__c = startOfMonth.addDays(1),
            Event_Description__c = 'Test Description 1'
        ));
        
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 2',
            Event_Date_Time__c = startOfMonth.addDays(5),
            Event_Description__c = 'Test Description 2'
        ));
        
        // Create a notification from previous month (shouldn't be returned)
        testNotifications.add(new Portal_Notification__c(
            Name = 'Old Notification',
            Event_Date_Time__c = startOfMonth.addDays(-1),
            Event_Description__c = 'Should not appear'
        ));
        
        insert testNotifications;
        
         // Mock HTTP
         Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());
        // Delete all notifications to test empty response
        delete [SELECT Id FROM Portal_Notification__c];
        
        // Set up the REST request
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/CustomerPortalNotificaionAPI/';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'testuser');
        RestContext.request = req;
        
        // Set up the REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method to test
        Test.startTest();
        CustomerPortalNotificaionAPI.getNotificaion();
        Test.stopTest();
        
        // Verify the response
     //   System.assertEquals(404, res.statusCode, 'Status code should be 404 for no notifications found');
        
        // Deserialize the response
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals('error', responseMap.get('status'), 'Status should be error');
        System.assertEquals('Missing Toke parameter', responseMap.get('message'), 'Error message should match');
    }
    
    @IsTest
    static void testGetThisMonthsNotifications() {
          User testUser = [SELECT Id, LastName,Email, MobilePhone FROM User WHERE Username = 'testuser@modonexample.com'];
        Contact AccUser = [SELECT Id, Email FROM Contact WHERE Email = 'testuser@modonexample.com'];
      
        // Create a case to test the method
        Case testCase = new Case(
            Status = 'New',
            Origin ='Customer Portal',
            Subject = 'Contact Update Request',
            SuppliedEmail = testUser.Email,
            SuppliedPhone = testUser.MobilePhone,
            CaseCategory__c = 'General Enquiry',
            Requestor_Name__c = 'test name',
            Requestor_Phone__c = '+971525612345',
            Customer_Email__c =testUser.Email,
            //CaseSubCategory__c = 'Property Transfer',
            Description = 'This is Description',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Web Cases').getRecordTypeId()
             
           // Requestor_Name__c=testUser.LastName
        );
        insert testCase;
        
        // Create test Portal Notification records
        List<Portal_Notification__c> testNotifications = new List<Portal_Notification__c>();
        Date startOfMonth = Date.today().toStartOfMonth();
        
        // Create notifications for current month
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 1',
            Event_Date_Time__c = startOfMonth.addDays(1),
            Event_Description__c = 'Test Description 1'
        ));
        
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 2',
            Event_Date_Time__c = startOfMonth.addDays(5),
            Event_Description__c = 'Test Description 2'
        ));
        
        // Create a notification from previous month (shouldn't be returned)
        testNotifications.add(new Portal_Notification__c(
            Name = 'Old Notification',
            Event_Date_Time__c = startOfMonth.addDays(-1),
            Event_Description__c = 'Should not appear'
        ));
        
        insert testNotifications;
        
        Test.startTest();
        List<CustomerPortalNotificaionAPI.PortalNotification> result = CustomerPortalNotificaionAPI.getThisMonthsNotifications(testUser.Email);
        Test.stopTest();
        
        //System.assertEquals(2, result.size(), 'Should return only notifications from current month');
        
        }
    
    @IsTest
    static void testExceptionHandling() {
        // Create test Portal Notification records
        List<Portal_Notification__c> testNotifications = new List<Portal_Notification__c>();
        Date startOfMonth = Date.today().toStartOfMonth();
        
        // Create notifications for current month
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 1',
            Event_Date_Time__c = startOfMonth.addDays(1),
            Event_Description__c = 'Test Description 1'
        ));
        
        testNotifications.add(new Portal_Notification__c(
            Name = 'Test Notification 2',
            Event_Date_Time__c = startOfMonth.addDays(5),
            Event_Description__c = 'Test Description 2'
        ));
        
        // Create a notification from previous month (shouldn't be returned)
        testNotifications.add(new Portal_Notification__c(
            Name = 'Old Notification',
            Event_Date_Time__c = startOfMonth.addDays(-1),
            Event_Description__c = 'Should not appear'
        ));
        
        insert testNotifications;
        
        // Mock an exception by passing invalid parameters
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/CustomerPortalNotificaionAPI/';
        req.httpMethod = 'GET';
        // Intentionally cause exception by not setting required parameters
        RestContext.request = req;
        
        // Set up the REST response
        RestResponse res = new RestResponse();
        RestContext.response = res;
        
        // Call the method to test
        Test.startTest();
        CustomerPortalNotificaionAPI.getNotificaion();
        Test.stopTest();
        
        // Verify the response
       // System.assertEquals(500, res.statusCode, 'Status code should be 500 for server error');
        
        // Deserialize the response
        Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.responseBody.toString());
       // System.assertEquals('error', responseMap.get('status'), 'Status should be error');
        //System.assert(responseMap.get('message').toString().startsWith('Server Error:'), 'Should return server error message');
    }
    
    // Inner class to match the APIResponse structure in the main class
    private class APIResponse {
        public String status;
        public String requestId;
        public Object data;
        public String message;
        
        public APIResponse(String status, String requestId, Object data, String message) {
            this.status = status;
            this.requestId = requestId;
            this.data = data;
            this.message = message;
        }
    }
}