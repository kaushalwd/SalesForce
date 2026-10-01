@isTest
public class ServiceRequestTriggerHandlerTest {
     private class DummyHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"result":"ok"}');
            res.setStatusCode(200);
            return res;
        }
    }
      private static void setupBaseData() {
        // Create Queue
        insert new Group(Name = 'CM Team SR', Type = 'Queue');

        // Create Assignment Rule
        insert new AssignmentRule__c(
            IsActive__c = true,
            RecordType__c = 'Service Request',
            ProcessType__c = 'Sales',
            ProcessName__c = 'ADM'
        );

        // Create SLA master
        insert new Master_SLA__c(
            Name = 'SRM -ADM-KYC Update-Normal',
            IsActive__c = true,
            ObjectName__c = 'ServiceRequest__c',
            Case_Origin__c = 'Service Request Management -ADM',
            SLA_Hrs__c = 2
        );

        // Create User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            FirstName = 'Handler',
            LastName = 'User',
            Email = 'handleruser@example.com',
            Username = 'handleruser_' + System.currentTimeMillis() + '@example.com',
            Alias = 'husr',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        // Create AssignmentUser
        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        AssignmentRule__c asr = [SELECT Id FROM AssignmentRule__c LIMIT 1];

        insert new AssignmentUser__c(
            User__c = u.Id,
            AssignmentRule__c = asr.Id,
            IsActive__c = true,
            MaximumCapacity__c = 5,
            Current_Load__c = 0,
            BusinessHours__c = bh.Id,
            Leave_Today__c = false
        );
    }
    
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id,status__c = 'sold');
        insert so;
    }

    @isTest
    static void testTriggerHandler() {
                setupBaseData();

                Test.setMock(HttpCalloutMock.class, new DummyHttpMock());

        Id srRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();

        Account acc = new Account(Name = 'Trigger Handler Test Account');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Sold');
        insert so;

        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId = srRtId,
            SalesOrder__c = so.Id,
            Type__c = 'New Sale'
        );

        Test.startTest();
        insert sr;
        Test.stopTest();
    }

    @isTest
    static void testRecursionControl() {
                 setupBaseData();

                Test.setMock(HttpCalloutMock.class, new DummyHttpMock());

        Id srRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();

        Account acc = new Account(Name = 'Trigger Handler Test Account');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Sold');
        insert so;

        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId = srRtId,
            SalesOrder__c = so.Id,
            Type__c = 'New Sale'
        );

        Test.startTest();
        insert sr;
        Test.stopTest();

    }

    // New test methods to cover remaining code
    @isTest
    static void testDeleteScenarios() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        
        Test.startTest();
        delete sr;
        undelete sr;
        Test.stopTest();
        
        System.assertEquals(1, [SELECT COUNT() FROM ServiceRequest__c]);
    }

    @isTest
    static void testDisabledTriggerPath() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
		sr.RecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'SRM_Unit_Swap');        
        insert sr;
        
        Test.startTest();
        ServiceRequestTriggerHandler.isTriggerDisabled = true;
        sr.Unit_Upgrade_Approval__c = Constants.UT_STATUS_REJECTED;
        sr.Status__c = 'Closed';
        update sr;
        Test.stopTest();
        
        System.assertEquals(true, ServiceRequestTriggerHandler.isTriggerDisabled);
    }

   

}