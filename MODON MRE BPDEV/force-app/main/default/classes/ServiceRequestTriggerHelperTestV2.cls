@IsTest
private class ServiceRequestTriggerHelperTestV2 {

    // Simple mock for any enqueued callouts PDFs etc.
    class DummyHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type','application/json');
            res.setBody('{}');
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    static void setupData() {
        // Mock callouts globally
        Test.setMock(HttpCalloutMock.class, new DummyHttpMock());

        // Ensure required Queues exist for assignment paths hit by beforeInsert()
        // - "CM Team SR"
        // - "CollectionTeam"
        insert new Group(Name='CM Team SR', Type='Queue');
        insert new Group(Name='CollectionTeam', Type='Queue');

        // Ensure a default BusinessHours exists (very defensive)
        BusinessHours bhDefault = null;
        try {
            bhDefault = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        } catch (Exception e) { }
        

        // Assignment Rule + User capacity records (used by ADM_SR_Assignment)
        AssignmentRule__c asr = new AssignmentRule__c(
            IsActive__c = true,
            RecordType__c = 'Service Request',
            ProcessType__c = 'Sales',
            DefaultQueueID__c = null,
            ProcessName__c = 'ADM'
        );
        insert asr;

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

        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];

        insert new AssignmentUser__c(
            User__c = u.Id,
            AssignmentRule__c = asr.Id,
            IsActive__c = true,
            MaximumCapacity__c = 10,
            Current_Load__c = 0,
            BusinessHours__c = bh.Id,
            Leave_Today__c = false
        );

        // Minimal SLA that SystemContextClass.getMasterSLADetailsForSR() can pick up
        insert new Master_SLA__c(
            Name = 'SRM -ADM-KYC Update-Normal',
            IsActive__c = true,
            Milestones__c = 'SRM -ADM-KYC Update-Normal',
            ObjectName__c = 'ServiceRequest__c',
            Case_Origin__c = 'Service Request Management -ADM',
            Category__c = Constants.SERVICE_REQUEST_TYPE_NEWSALE,
            SLA_Hrs__c = 2,
            Is_Available_For_Extension__c = true
        );

        // Base data used by multiple tests
        Account acc = new Account(Name='Test Account');
        insert acc;

        insert new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c='Sold');
    }

    // Helper to get RT Id by dev name safely
    private static Id rtId(String sobjectApi, String devName) {
        return Schema.getGlobalDescribe().get(sobjectApi)
            .getDescribe().getRecordTypeInfosByDeveloperName().get(devName).getRecordTypeId();
    }

   
    @IsTest
    static void test_plot_default_cancellation_uc_and_uc_approval() {
        Id plotRtId   = rtId('ServiceRequest__c','Service_Request_Plot_Handover');
        Id defaultRt  = rtId('ServiceRequest__c','Default_SR');
        Id cancelRt   = rtId('ServiceRequest__c','DefaultUnitCancellation');
        Id ucRt       = rtId('ServiceRequest__c','Unit_Consolidation');

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        ServiceRequest__c srPlot = new ServiceRequest__c(SalesOrder__c=so.Id, RecordTypeId=plotRtId,   Type__c='New Sale');
        ServiceRequest__c srDef  = new ServiceRequest__c(SalesOrder__c=so.Id, RecordTypeId=defaultRt,  Type__c='New Sale');
        ServiceRequest__c srCan  = new ServiceRequest__c(SalesOrder__c=so.Id, RecordTypeId=cancelRt,  Type__c='New Sale');
        ServiceRequest__c srUc   = new ServiceRequest__c(SalesOrder__c=so.Id, RecordTypeId=ucRt,      Type__c='New Sale');

        Test.startTest();
        insert new List<ServiceRequest__c>{ srPlot, srDef, srCan, srUc };

        // Drive UC approval & rejection branches
        srUc.Unit_Consolidation_Approvals__c = Constants.PE_APPROVAL_STATUS;
        update srUc;
        srUc.Unit_Consolidation_Approvals__c = Constants.PE_REJECTION_STATUS;
        update srUc;
        Test.stopTest();
    }
}