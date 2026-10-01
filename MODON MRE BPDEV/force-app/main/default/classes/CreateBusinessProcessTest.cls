@isTest
public class CreateBusinessProcessTest {

    @testSetup
    static void setupData() {

       Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'BR Amendment',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test',
            Type__c='Cost Approval'
        );
        insert testProcessFlow;


        // -------------------------
        // Flow Steps
        // -------------------------
        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow.Id,
            isSingleUser__c=true
        );
        insert pfs1;

        // -------------------------
        // Flow Document (IMPORTANT for second loop)
        // -------------------------
        Process_Flow_Document__c doc = new Process_Flow_Document__c(
            Name = 'Test Doc',
            Process_Flow__c = testProcessFlow.Id,
            Active__c = true,
            Process_Flow_Step__c = pfs1.Id
        );
        insert doc;

        // -------------------------
        // Sales Order (for SO path)
        // -------------------------
        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id
        );
        insert so;
          Project__c project = new Project__c(
            Name = 'Test Project'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;
        
          Milestone__c milestone = new Milestone__c(
            Name = 'Milestone 1',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today().addDays(-20)
        );
        insert milestone;
    }
     @isTest
    static void testGetProcessFlowsForBooking() {
        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'tusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = [SELECT Id FROM Profile LIMIT 1].Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        AppoinmentBooking__c testBooking = new AppoinmentBooking__c(
            Appoinment_Date__c = System.now(),
            Email__c = u.Email
        );
        
        insert testBooking;
       
        Test.startTest();
        List<Process_Flow__c> result = CreateBusinessProcess.getProcessFlows(testBooking.Id);
        Test.stopTest();
    }

    // -------------------------
    // TEST 1: SalesOrder flow
    // -------------------------
    @isTest
    static void testCreatePreRegistration_SalesOrder() {

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Process_Flow__c flow = [SELECT Id FROM Process_Flow__c LIMIT 1];
        
        Milestone__c mile=[Select Id from Milestone__c LIMIT 1 ];

        Test.startTest();
        String result = CreateBusinessProcess.createPreRegistration(
            so.Id,
            flow.Id
        );
        Test.stopTest();
         String result1 = CreateBusinessProcess.createPreRegistration(
            mile.Id,
            flow.Id
        );
    }

    // -------------------------
    // TEST 2: Invalid input
    // -------------------------
    @isTest
    static void testCreatePreRegistration_Invalid() {

        Test.startTest();
        String result = CreateBusinessProcess.createPreRegistration('', '');
        Test.stopTest();
    }

    // -------------------------
    // TEST 3: Booking-style null path safety
    // -------------------------
    @isTest
    static void testCreatePreRegistration_NoSalesOrderData() {

        Process_Flow__c flow = [SELECT Id FROM Process_Flow__c LIMIT 1];

        Test.startTest();
        String result = CreateBusinessProcess.createPreRegistration(
            'a01xx0000000001AAA',
            flow.Id
        );
        Test.stopTest();
    }
@isTest
static void testCreateBusinessProcessStepDirect() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;

      Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment1',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test1',
            Type__c='Cost Approval'
        );
        insert testProcessFlow1;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Active__c=true,
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Active__c=true,
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow1.Id
        );
        insert bp;

    Test.startTest();

    Business_Process_Step__c result =
        CreateBusinessProcess.createBusinessProcessStep(
            1,
            pfs1,
            bp.Id,
            null,
            null
        );

    Test.stopTest();

}
    
    
@isTest
static void testCreateBusinessProcessStepDirect1() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;

      Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment1',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test1',
            Type__c='Cost Approval'
        );
        insert testProcessFlow1;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id,
             isSingleUser__c=true,
            Active__c=true
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id,
             isSingleUser__c=true,
            Active__c=true
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow1.Id
        );
        insert bp;

    Test.startTest();

    Business_Process_Step__c result =
        CreateBusinessProcess.createBusinessProcessStep(
            1,
            pfs1,
            bp.Id,
            null,
            null
        );

    Test.stopTest();

}
    
@isTest
static void testCreateBusinessProcessStepDirect2() {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;

      Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment1',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test1',
            Type__c='Cost Approval'
        );
        insert testProcessFlow1;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id,
             isSingleUser__c=true,
            Activate_On_Creation__c=true,
            Dont_Activate__c=true,
            Active__c=true
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id,
            isSingleUser__c=true,
            Activate_On_Creation__c=true,
            Active__c=true
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow1.Id
        );
        insert bp;

    Test.startTest();
    SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
    
    Business_Process_Step__c result =
        CreateBusinessProcess.createBusinessProcessStep(
            1,
            pfs1,
            bp.Id,
       so,
            null
        );

    Test.stopTest();

}



}