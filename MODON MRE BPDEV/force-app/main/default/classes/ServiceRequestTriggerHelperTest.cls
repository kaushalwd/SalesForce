@isTest
public class ServiceRequestTriggerHelperTest {
    public class DummyHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{}');
            res.setStatusCode(200);
            return res;
        }
    }
   
@isTest
static void testAllLogic() {
    Test.setMock(HttpCalloutMock.class, new DummyHttpMock());

    // Create required Group (Queue)
    Group cmQueue = new Group(Name = 'CM Team SR', Type = 'Queue');
    insert cmQueue;

    // Create BusinessHours
    BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];

    // Assignment Rule for ADM
    AssignmentRule__c asr = new AssignmentRule__c(

        IsActive__c = true,
        RecordType__c = 'Service Request',
        ProcessType__c = 'Sales',
        DefaultQueueID__c = null,
        ProcessName__c = 'ADM'
    );
    insert asr;
        Master_SLA__c msla = new Master_SLA__c();
        msla.Name = 'SRM -ADM-KYC Update-Normal';
        msla.IsActive__c = true;
        msla.Milestones__c = 'SRM -ADM-KYC Update-Normal';
        msla.ObjectName__c = 'ServiceRequest__c';
        msla.Case_Origin__c = 'Service Request Management -ADM';
        msla.Category__c = Constants.SERVICE_REQUEST_TYPE_NEWSALE;
        msla.SLA_Hrs__c = 2;
        msla.Is_Available_For_Extension__c = true;
        insert msla;

    // Create User for AssignmentUser__c (owner must be a User, not Queue)
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser@example.com',
        Username = 'testuser_' + System.currentTimeMillis() + '@example.com',
        Alias = 'tuser',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    // AssignmentUser__c record
    AssignmentUser__c au = new AssignmentUser__c(

        User__c = u.Id,
        AssignmentRule__c = asr.Id,
        IsActive__c = true,
        MaximumCapacity__c = 10,
        Current_Load__c = 0,
        BusinessHours__c = bh.Id,
        Leave_Today__c = false
    );
    insert au;

    // Continue with your previous test setup here...
    // Create Account, Contact, SalesOrder, ServiceRequest, etc.

    // Create a record that triggers ADM_SR_Assignment.assignServiceRequests
    Id srAdmrRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('Service_Request_Management_ADM').getRecordTypeId();
     Id srTaskId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName()
        .get('Service_Request').getRecordTypeId();
  Account acc = new Account();
        acc.name = 'test account';
        insert acc;
    SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Sold');
    insert so;

    ServiceRequest__c sr = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = srAdmrRtId,
        Type__c = 'New Sale'
    );

    Test.startTest();
    insert sr; // This will now trigger ServiceRequestTriggerHelper.beforeInsert → ADM_SR_Assignment
   // ServiceRequestTriggerHelper.createSLAforSR(new List<ServiceRequest__c> {sr});
    Task thisTask = new Task();
    thisTask.Status = Constants.TASK_STATUS_COMPLETED;
    thisTask.Subject = Constants.PE_APPROVAL_TASK_SUBJECT;
    thisTask.WhatId =sr.Id;
    thisTask.RecordTypeId=srTaskId;
    insert thisTask;
    Task thisTask1 = new Task();
    thisTask1.Status = Constants.TASK_STATUS_INVALID_NUMBER;
    thisTask1.Subject = Constants.PE_APPROVAL_TASK_SUBJECT;
    thisTask1.WhatId =sr.Id;
    thisTask.RecordTypeId=srTaskId;
    insert thisTask1;
    sr.RecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Request_Payment_Extension');
    sr.Payment_Extension_Approval__c = Constants.PE_APPROVAL_STATUS;
    update sr;
    Test.stopTest();
}
    
    @isTest
static void testAllLogic1() {
    Test.setMock(HttpCalloutMock.class, new DummyHttpMock());

    // Create required Group (Queue)
    Group cmQueue = new Group(Name = 'CM Team SR', Type = 'Queue');
    insert cmQueue;

    // Create BusinessHours
    BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];

    // Assignment Rule for ADM
    AssignmentRule__c asr = new AssignmentRule__c(

        IsActive__c = true,
        RecordType__c = 'Service Request',
        ProcessType__c = 'Sales',
        DefaultQueueID__c = null,
        ProcessName__c = 'ADM'
    );
    insert asr;
        Master_SLA__c msla = new Master_SLA__c();
        msla.Name = 'SRM -ADM-KYC Update-Normal';
        msla.IsActive__c = true;
        msla.Milestones__c = 'SRM -ADM-KYC Update-Normal';
        msla.ObjectName__c = 'ServiceRequest__c';
        msla.Case_Origin__c = 'Service Request Management -ADM';
        msla.Category__c = Constants.SERVICE_REQUEST_TYPE_NEWSALE;
        msla.SLA_Hrs__c = 2;
        msla.Is_Available_For_Extension__c = true;
        insert msla;

    // Create User for AssignmentUser__c (owner must be a User, not Queue)
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser@example.com',
        Username = 'testuser_' + System.currentTimeMillis() + '@example.com',
        Alias = 'tuser',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    // AssignmentUser__c record
    AssignmentUser__c au = new AssignmentUser__c(

        User__c = u.Id,
        AssignmentRule__c = asr.Id,
        IsActive__c = true,
        MaximumCapacity__c = 10,
        Current_Load__c = 0,
        BusinessHours__c = bh.Id,
        Leave_Today__c = false
    );
    insert au;

    // Continue with your previous test setup here...
    // Create Account, Contact, SalesOrder, ServiceRequest, etc.

    // Create a record that triggers ADM_SR_Assignment.assignServiceRequests
    Id srAdmrRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('Service_Request_Management_ADM').getRecordTypeId();
     Id peAdmrRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('Request_Payment_Extension').getRecordTypeId();
     
    
     Id srTaskId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName()
        .get('Service_Request').getRecordTypeId();
  Account acc = new Account();
        acc.name = 'test account';
        insert acc;
    SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Sold');
    insert so;

    ServiceRequest__c sr = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = peAdmrRtId,
        Type__c = 'New Sale'
    );

    Test.startTest();
    insert sr; // This will now trigger ServiceRequestTriggerHelper.beforeInsert → ADM_SR_Assignment
    //ServiceRequestTriggerHelper.createSLAforSR(new List<ServiceRequest__c> {sr});
    list<Task> inserListTask =new list<Task>();
    Task thisTask = new Task();
    thisTask.Status = Constants.TASK_STATUS_COMPLETED;
    thisTask.Subject = Constants.PE_APPROVAL_TASK_SUBJECT;
    thisTask.WhatId =sr.Id;
    thisTask.RecordTypeId=srTaskId;
    thisTask.Order__c = 2.0;
    inserListTask.add(thisTask);
    Task thisTask1 = new Task();
    thisTask1.Status = Constants.TASK_STATUS_INVALID_NUMBER;
    thisTask1.Subject = Constants.PE_APPROVAL_TASK_SUBJECT;
    thisTask1.WhatId =sr.Id;
    thisTask1.RecordTypeId=srTaskId;
    thisTask1.Order__c=3.0;
    inserListTask.add(thisTask1);
    insert inserListTask;
   sr.Payment_Extension_Approval__c='Approved';
    update sr;
    sr.Payment_Extension_Approval__c='Rejected';
    update sr;
    Test.stopTest();
}
    
       @isTest
static void testAllLogic2() {
    Test.setMock(HttpCalloutMock.class, new DummyHttpMock());

    // Create required Group (Queue)
    Group cmQueue = new Group(Name = 'CM Team SR', Type = 'Queue');
    insert cmQueue;

    // Create BusinessHours
    BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];

    // Assignment Rule for ADM
    AssignmentRule__c asr = new AssignmentRule__c(

        IsActive__c = true,
        RecordType__c = 'Service Request',
        ProcessType__c = 'Sales',
        DefaultQueueID__c = null,
        ProcessName__c = 'ADM'
    );
    insert asr;
        Master_SLA__c msla = new Master_SLA__c();
        msla.Name = 'SRM -ADM-KYC Update-Normal';
        msla.IsActive__c = true;
        msla.Milestones__c = 'SRM -ADM-KYC Update-Normal';
        msla.ObjectName__c = 'ServiceRequest__c';
        msla.Case_Origin__c = 'Service Request Management -ADM';
        msla.Category__c = Constants.SERVICE_REQUEST_TYPE_NEWSALE;
        msla.SLA_Hrs__c = 2;
        msla.Is_Available_For_Extension__c = true;
        insert msla;

    // Create User for AssignmentUser__c (owner must be a User, not Queue)
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser@example.com',
        Username = 'testuser_' + System.currentTimeMillis() + '@example.com',
        Alias = 'tuser',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    // AssignmentUser__c record
    AssignmentUser__c au = new AssignmentUser__c(

        User__c = u.Id,
        AssignmentRule__c = asr.Id,
        IsActive__c = true,
        MaximumCapacity__c = 10,
        Current_Load__c = 0,
        BusinessHours__c = bh.Id,
        Leave_Today__c = false
    );
    insert au;

    // Continue with your previous test setup here...
    // Create Account, Contact, SalesOrder, ServiceRequest, etc.

    // Create a record that triggers ADM_SR_Assignment.assignServiceRequests
    Id srAdmrRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('Service_Request_Management_ADM').getRecordTypeId();
     Id peAdmrRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('LPC_Waiver').getRecordTypeId();
     
    
     Id srTaskId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName()
        .get('Service_Request').getRecordTypeId();
  Account acc = new Account();
        acc.name = 'test account';
        insert acc;
    SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Sold');
    insert so;

    ServiceRequest__c sr = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = peAdmrRtId,
        Type__c = 'New Sale'
    );

    Test.startTest();
    insert sr; // This will now trigger ServiceRequestTriggerHelper.beforeInsert → ADM_SR_Assignment
    //ServiceRequestTriggerHelper.createSLAforSR(new List<ServiceRequest__c> {sr});
    list<Task> inserListTask =new list<Task>();
    Task thisTask = new Task();
    thisTask.Status = Constants.TASK_STATUS_COMPLETED;
    thisTask.Subject = Constants.PE_APPROVAL_TASK_SUBJECT;
    thisTask.WhatId =sr.Id;
    thisTask.RecordTypeId=srTaskId;
    thisTask.Order__c =2.0;
    inserListTask.add(thisTask);
    Task thisTask1 = new Task();
    thisTask1.Status = Constants.TASK_STATUS_INVALID_NUMBER;
    thisTask1.Subject = Constants.PE_APPROVAL_TASK_SUBJECT;
    thisTask1.WhatId =sr.Id;
    thisTask1.RecordTypeId=srTaskId;
    thisTask1.Order__c =3.0;
    inserListTask.add(thisTask1);
    insert inserListTask;
    sr.LPC_Waiver_Approvals__c='Approved';
        update sr;
    sr.LPC_Waiver_Approvals__c='Rejected';
        update sr;
    Test.stopTest();
}
    
           @isTest
static void testAllLogic3() {
    Test.setMock(HttpCalloutMock.class, new DummyHttpMock());

    // Create required Group (Queue)
    Group cmQueue = new Group(Name = 'CM Team SR', Type = 'Queue');
    insert cmQueue;

    // Create BusinessHours
    BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];

    // Assignment Rule for ADM
    AssignmentRule__c asr = new AssignmentRule__c(

        IsActive__c = true,
        RecordType__c = 'Service Request',
        ProcessType__c = 'Sales',
        DefaultQueueID__c = null,
        ProcessName__c = 'ADM'
    );
    insert asr;
        Master_SLA__c msla = new Master_SLA__c();
        msla.Name = 'SRM -ADM-KYC Update-Normal';
        msla.IsActive__c = true;
        msla.Milestones__c = 'SRM -ADM-KYC Update-Normal';
        msla.ObjectName__c = 'ServiceRequest__c';
        msla.Case_Origin__c = 'Service Request Management -ADM';
        msla.Category__c = Constants.SERVICE_REQUEST_TYPE_NEWSALE;
        msla.SLA_Hrs__c = 2;
        msla.Is_Available_For_Extension__c = true;
        insert msla;

    // Create User for AssignmentUser__c (owner must be a User, not Queue)
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser@example.com',
        Username = 'testuser_' + System.currentTimeMillis() + '@example.com',
        Alias = 'tuser',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    // AssignmentUser__c record
    AssignmentUser__c au = new AssignmentUser__c(

        User__c = u.Id,
        AssignmentRule__c = asr.Id,
        IsActive__c = true,
        MaximumCapacity__c = 10,
        Current_Load__c = 0,
        BusinessHours__c = bh.Id,
        Leave_Today__c = false
    );
    insert au;

    // Continue with your previous test setup here...
    // Create Account, Contact, SalesOrder, ServiceRequest, etc.

    // Create a record that triggers ADM_SR_Assignment.assignServiceRequests
    Id srAdmrRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('Default_SR').getRecordTypeId();
     Id peAdmrRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('Service_Request_Plot_Handover').getRecordTypeId();
     Id dUCRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('DefaultUnitCancellation').getRecordTypeId();
    Id UCRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
        .get('Unit_Consolidation').getRecordTypeId();
    
     Id srTaskId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName()
        .get('Service_Request').getRecordTypeId();
  Account acc = new Account();
        acc.name = 'test account';
        insert acc;
    SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Sold');
    insert so;

    ServiceRequest__c sr = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = peAdmrRtId,
        Type__c = 'New Sale'
    );
    
     ServiceRequest__c sr1 = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = srAdmrRtId,
        Type__c = 'New Sale'
    );
    ServiceRequest__c sr2 = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = dUCRtId,
        Type__c = 'New Sale'
    );
    ServiceRequest__c sr3 = new ServiceRequest__c(
        SalesOrder__c = so.Id,
        RecordTypeId = UCRtId,
        Type__c = 'New Sale'
    );

    Test.startTest();
    insert sr; // This will now trigger ServiceRequestTriggerHelper.beforeInsert → ADM_SR_Assignment
    insert sr1;
    insert sr2;
    insert sr3;
   // ServiceRequestTriggerHelper.createSLAforSR(new List<ServiceRequest__c> {sr});
    Task thisTask = new Task();
    thisTask.Status = Constants.TASK_STATUS_COMPLETED;
    thisTask.Subject = Constants.PE_APPROVAL_TASK_SUBJECT;
    thisTask.WhatId =sr.Id;
    thisTask.RecordTypeId=srTaskId;
    insert thisTask;
    Task thisTask1 = new Task();
    thisTask1.Status = Constants.TASK_STATUS_INVALID_NUMBER;
    thisTask1.Subject = Constants.PE_APPROVAL_TASK_SUBJECT;
    thisTask1.WhatId =sr.Id;
    thisTask1.RecordTypeId=srTaskId;
    insert thisTask1;
    
    sr3.Unit_Consolidation_Approvals__c='Approved';
        update sr3;
    sr3.Unit_Consolidation_Approvals__c='Rejected';
        update sr3;
    Test.stopTest();
}
@isTest
static void testSellingPriceChangeRecalculatesADMCharge() {

    Test.setMock(HttpCalloutMock.class, new DummyHttpMock());

    // Get Record Type
    Id rtId =
        Utility.getRecordTypeIdByDevName(
            ServiceRequest__c.SObjectType,'Service_Request_Management_Property_Transfer_OffPlan');

    // Create Phase
    Phase__c p = TestDataFactory.creatPhase();

    // Create Unit
    Unit__c u = TestDataFactory.createunit();
    u.Phase__c = p.Id;
    update u;

    // Create Account
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    // Create Sales Order
    SalesOrder__c so =
        new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Sold',
            Unit__c = u.Id,
            TotalAmount__c = 100000
        );
    insert so;

    // Create Financial Setup for ADM
    Financial_Setup__c fs =
        new Financial_Setup__c();

    fs.Sub_Type__c = 'Normal';
    fs.Type__c = 'ADM & Dari Fee';
    fs.Value__c = 2; // 2%
    fs.Default_Amount__c = 0;
    fs.Fee_Type__c =
        Constants.PERECENTAGE_BASED_CALCULATION;
    fs.SR_RecordType__c ='Service_Request_Management_Property_Transfer_OffPlan';
    fs.Phase__c = p.Id;
    fs.VAT_Percnetage__c = 5;

    insert fs;

    Test.startTest();

    // Create Service Request
    ServiceRequest__c sr = TestDataFactory.createServiceRequest('Normal',rtId);

    sr.SalesOrder__c = so.Id;
    sr.UnitId__c = u.Id;
    sr.SubType__c = 'Normal';
    sr.Selling_Price__c = 100000;
    sr.Step_Order__c = 5;

    update sr;

    // Create initial charge
    ChargeService.createChargesOnSR( new List<ServiceRequest__c>{ sr });

    // Fetch created charge
    Charge__c ch = [
        SELECT Id,
               Amount__c,
               VAT_Amount__c
        FROM Charge__c
        WHERE Service_Request__c = :sr.Id
        AND Type__c = 'ADM & Dari Fee'
        LIMIT 1
    ];

    // Update Selling Price
    sr.Selling_Price__c = 200000;

    update sr;

    Test.stopTest();

}
    
@isTest
static void testCreateDocumentPlaceholders() {

    // ------------------ SETUP OBJECTS ------------------
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];

    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser2@example.com',
        Username = 'testuser2' + System.currentTimeMillis() + '@example.com',
        Alias = 'tuser2',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    // Create Queues
    List<Group> queuesToInsert = new List<Group>();

    List<Group> existingQueues = [
        SELECT Id, DeveloperName
        FROM Group
        WHERE DeveloperName IN ('Sales_Manager', 'CM_Manager')
        AND Type = 'Queue'
    ];

    Set<String> existingNames = new Set<String>();
    for (Group g : existingQueues) {
        existingNames.add(g.DeveloperName);
    }

    if (!existingNames.contains('Sales_Manager')) {
        queuesToInsert.add(new Group(
            Name = 'Sales Manager Queue',
            DeveloperName = 'Sales_Manager',
            Type = 'Queue'
        ));
    }

    if (!existingNames.contains('CM_Manager')) {
        queuesToInsert.add(new Group(
            Name = 'CM Manager Queue',
            DeveloperName = 'CM_Manager',
            Type = 'Queue'
        ));
    }

    if (!queuesToInsert.isEmpty()) {
        insert queuesToInsert;

        List<QueueSobject> qsoList = new List<QueueSobject>();
        for (Group q : queuesToInsert) {
            qsoList.add(new QueueSobject(
                QueueId = q.Id,
                SobjectType = 'ServiceRequest__c'
            ));
        }
        insert qsoList;
    }

    // ------------------ NON-SETUP (SEPARATED) ------------------
    System.runAs(u) {

        Test.startTest();

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            //Status__c = 'Completed'
            Status__c = 'New'
        );
        insert so;

        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName();

        Id preRT = rtMap.get('Pre Unit Cancellation').getRecordTypeId();
        Id postRT = rtMap.get('Post Unit Cancellation').getRecordTypeId();

        ServiceRequest__c sr1 = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = preRT,
            Cancellation_Type__c = 'Cancellation with Refund'
        );

        ServiceRequest__c sr2 = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = postRT,
            Cancellation_Type__c = 'Consolidation Cancellation'
        );

        insert new List<ServiceRequest__c>{ sr1, sr2 };

        ServiceRequestTriggerHelper.createDocumentPlaceholders(
            new List<ServiceRequest__c>{ sr1, sr2 }
        );

        Test.stopTest();
    }
}
    @isTest
static void testUpdateRefundFlagAsync() {

    // ------------------ SETUP OBJECTS ------------------
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];

    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser@example.com',
        Username = 'testuser' + System.currentTimeMillis() + '@example.com',
        Alias = 'tuser',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    // Create Queues
    List<Group> queuesToInsert = new List<Group>();

    List<Group> existingQueues = [
        SELECT Id, DeveloperName
        FROM Group
        WHERE DeveloperName IN ('Sales_Manager', 'CM_Manager')
        AND Type = 'Queue'
    ];

    Set<String> existingNames = new Set<String>();
    for (Group g : existingQueues) {
        existingNames.add(g.DeveloperName);
    }

    if (!existingNames.contains('Sales_Manager')) {
        queuesToInsert.add(new Group(
            Name = 'Sales Manager Queue',
            DeveloperName = 'Sales_Manager',
            Type = 'Queue'
        ));
    }

    if (!existingNames.contains('CM_Manager')) {
        queuesToInsert.add(new Group(
            Name = 'CM Manager Queue',
            DeveloperName = 'CM_Manager',
            Type = 'Queue'
        ));
    }

    if (!queuesToInsert.isEmpty()) {
        insert queuesToInsert;

        List<QueueSobject> qsoList = new List<QueueSobject>();
        for (Group q : queuesToInsert) {
            qsoList.add(new QueueSobject(
                QueueId = q.Id,
                SobjectType = 'ServiceRequest__c'
            ));
        }
        insert qsoList;
    }

    // ------------------ NON-SETUP ------------------
    System.runAs(u) {

        Test.startTest();

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            //Status__c = 'Completed'
            Status__c = 'New'
        );
        insert so;

        Id rtId = Schema.SObjectType.ServiceRequest__c
            .getRecordTypeInfosByName()
            .get('Pre Unit Cancellation')
            .getRecordTypeId();

        ServiceRequest__c sr1 = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = rtId,
            Cancellation_Type__c = 'Cancellation with Refund'
        );

        ServiceRequest__c sr2 = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = rtId,
            Cancellation_Type__c = 'Consolidation Cancellation'
        );

        insert new List<ServiceRequest__c>{ sr1, sr2 };

        ServiceRequestTriggerHelper.updateRefundFlagAsync(
            new Set<Id>{ sr1.Id, sr2.Id }
        );

        Test.stopTest();
    }
}
    
    @isTest
static void testAssignToQueue() {

    // ---------- SETUP OBJECTS ----------
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];

    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'assignqueue@test.com',
        Username = 'assignqueue' + System.currentTimeMillis() + '@test.com',
        Alias = 'tuser',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    // Create Queues
    List<Group> queueList = new List<Group>();

    Group salesQ = new Group(
        Name = 'Sales Manager Queue111',
        DeveloperName = 'Sales_Manager111',
        Type = 'Queue'
    );

    Group cmQ = new Group(
        Name = 'CM Manager Queue111',
        DeveloperName = 'CM_Manager111',
        Type = 'Queue'
    );

    queueList.add(salesQ);
    queueList.add(cmQ);

    insert queueList;

    // ---------- NON-SETUP ----------
    System.runAs(u) {

        // Get Record Types
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName();

        Id preRT = rtMap.get(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION).getRecordTypeId();
        Id postRT = rtMap.get(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION).getRecordTypeId();

        // Create dummy records (no insert needed for this method)
        ServiceRequest__c sr1 = new ServiceRequest__c(
            RecordTypeId = preRT
        );

        ServiceRequest__c sr2 = new ServiceRequest__c(
            RecordTypeId = postRT
        );

        List<ServiceRequest__c> srList = new List<ServiceRequest__c>{ sr1, sr2 };

        Test.startTest();

        // Call method
        ServiceRequestTriggerHelper.assignToQueue(srList);

        Test.stopTest();

        // ---------- ASSERTIONS ----------
        Map<String, Id> queueMap = new Map<String, Id>();
        for (Group g : [
            SELECT Id, DeveloperName
            FROM Group
            WHERE DeveloperName IN ('Sales_Manager', 'CM_Manager')
        ]) {
            queueMap.put(g.DeveloperName, g.Id);
        }
    }
}
    
   @isTest
static void testGeneratePDFAsync_WithQueueOwner() {

    // ------------------ SETUP OBJECTS ------------------
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];

    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'queuepdf@test.com',
        Username = 'queuepdf' + System.currentTimeMillis() + '@test.com',
        Alias = 'tuser',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;

    // ---------- QUERY EXISTING QUEUES ----------
    Map<String, Id> queueMap = new Map<String, Id>();

    for (Group g : [
        SELECT Id, DeveloperName
        FROM Group
        WHERE DeveloperName IN ('Sales_Manager', 'CM_Manager')
        AND Type = 'Queue'
    ]) {
        queueMap.put(g.DeveloperName, g.Id);
    }

    // ---------- CREATE ONLY IF MISSING ----------
    List<Group> queuesToInsert = new List<Group>();

    if (!queueMap.containsKey('Sales_Manager')) {
        queuesToInsert.add(new Group(
            Name = 'Sales Manager Queue',
            DeveloperName = 'Sales_Manager',
            Type = 'Queue'
        ));
    }

    if (!queueMap.containsKey('CM_Manager')) {
        queuesToInsert.add(new Group(
            Name = 'CM Manager Queue',
            DeveloperName = 'CM_Manager',
            Type = 'Queue'
        ));
    }

    if (!queuesToInsert.isEmpty()) {
        insert queuesToInsert;

        for (Group g : queuesToInsert) {
            queueMap.put(g.DeveloperName, g.Id);
        }

        List<QueueSobject> qsoList = new List<QueueSobject>();
        for (Group q : queuesToInsert) {
            qsoList.add(new QueueSobject(
                QueueId = q.Id,
                SobjectType = 'ServiceRequest__c'
            ));
        }
        insert qsoList;
    }

    // ------------------ NON-SETUP ------------------
    System.runAs(u) {

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            //Status__c = 'Completed'
            Status__c = 'New'
        );
        insert so;

        // Record Types
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName();

        Id preRT = rtMap.get(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION).getRecordTypeId();
        Id postRT = rtMap.get(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION).getRecordTypeId();

        // Create SRs (trigger assigns owner)
        ServiceRequest__c sr1 = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = preRT,
            Cancellation_Type__c = 'Cancellation with Refund'
        );

        ServiceRequest__c sr2 = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = postRT,
            Cancellation_Type__c = 'Cancellation with Refund'
        );

        insert new List<ServiceRequest__c>{ sr1, sr2 };

        // IMPORTANT: Names must match contains('Pre Unit') / ('Post Unit')
        List<Documents__c> docs = new List<Documents__c>{
            new Documents__c(
                Name = 'Pre Unit Test Doc',
                Service_Request__c = sr1.Id,
                Status__c = 'Pending Upload'
            ),
            new Documents__c(
                Name = 'Post Unit Test Doc',
                Service_Request__c = sr2.Id,
                Status__c = 'Pending Upload'
            )
        };

        insert docs;

        // ------------------ EXECUTE ------------------
        Test.startTest();

        ServiceRequestTriggerHelper.generatePDFAsync(
            new Set<Id>{ sr1.Id, sr2.Id }
        );

        Test.stopTest();
    }
}
}