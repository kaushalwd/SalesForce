@isTest
private class ADM_SR_AssignmentTest {  
    private static final String SERVICE_REQUEST_RT_DEV_NAME_ADM = 'Service_Request_Management_ADM';
    private static final string SERVICE_REQUEST_RT_Unit_SWAP { get { return 'SRM_Unit_Swap'; } } 
    private static Id unitswapRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_SWAP);
    private static String  admrRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get(SERVICE_REQUEST_RT_DEV_NAME_ADM).getRecordTypeId();
    
    
    
    
    @testSetup
    static void setupTestData() {

        // Create Accounts and Contacts needed for email testing
        Id personAccountRT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Id businessAccountRT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        
        // Create Person Account
        Account personAcc = new Account(
            FirstName = 'Test',
            LastName = 'Person',
            RecordTypeId = personAccountRT,
            PersonEmail = 'testperson@test.com'
        );
        insert personAcc;
        
        // Create Business Account
        Account businessAcc = new Account(
            Name = 'Test Business',
            RecordTypeId = businessAccountRT
        );
        insert businessAcc;
        
        // Create Contact for Business Account
        Contact businessContact = new Contact(
            FirstName = 'Business',
            LastName = 'Contact',
            AccountId = businessAcc.Id,
            Email = 'businesscontact2302@test.com',
            Is_Active__c = true
        );
        insert businessContact;
        
        // Create a Sales Order (if required by triggers)
        salesorder__c so = new salesorder__c(
            Status__c = 'Sold',
            CustomerAccount__c = personAcc.Id // Link to person account
        );
        insert so;
        
        // Create another Sales Order for business account
        salesorder__c businessSO = new salesorder__c(
            Status__c = 'Sold',
            CustomerAccount__c = businessAcc.Id // Link to business account
        );
        insert businessSO;
        
        // Get RecordTypeIds
        
        
        // Insert AssignmentRule__c for ADM_SR_Assignment logic
       
        
        AssignmentRule__c asr = new AssignmentRule__c(
            IsActive__c = true,
            Recordtype__C = 'service Request',
            ProcessName__c = 'ADM',
            ProcessType__c = 'Sales'
        );
        insert asr;    
 
        
Group testQueue = new Group(
        Name = 'CM Team SR Test',
        Type = 'Queue'
    );
    insert testQueue;
    System.debug('DEBUG: Test Queue inserted - ID: ' + testQueue.Id);
        
        AssignmentRule__c asr2 = new AssignmentRule__c(
            IsActive__c = true,
            Recordtype__C = 'service Request',
            ProcessName__c = 'Plot Handover',
            ProcessType__c = 'Sales',
            DefaultQueueID__c = testQueue.Id   
        );
        insert asr2;  
        System.debug('asr2----->'+asr2);
        AssignmentRule__c asrsolq=[SELECT Id FROM AssignmentRule__c 
                WHERE IsActive__c = true AND 
                ProcessName__c ='Plot Handover' AND ProcessType__c ='Sales' 
                AND DefaultQueueID__c =:testQueue.Id
                order by createddate desc LIMIT 1];
        
        
                System.debug('asr2 QUERY----->'+asrsolq);

        // Insert a user to assign (must be active)
        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'testuser' + Math.random() + '@example.com'
        );
        insert testUser;
        // Insert a user to assign (must be active)
        User testUser1 = new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            Username = 'testuser' + Math.random() + '@example.com'
        );
        insert testUser1;
        
     AssignmentUser__c au = new AssignmentUser__c(
    User__c = testUser.Id,
    AssignmentRule__c = asr.Id,
    IsActive__c = true,
    Current_Load__c = 1,
    MaximumCapacity__c = 15,

    // Monday
    MondayStartTime__c = Time.newInstance(8, 0, 0, 0),
    MondayEndTime__c   = Time.newInstance(18, 0, 0, 0),

    // Tuesday
    TuesdayStartTime__c = Time.newInstance(8, 0, 0, 0),
    TuesdayEndTime__c   = Time.newInstance(18, 0, 0, 0),

    // Wednesday
    WednesdayStartTime__c = Time.newInstance(8, 0, 0, 0),
    WednesdayEndTime__c   = Time.newInstance(18, 0, 0, 0),

    // Thursday
    ThursdayStartTime__c = Time.newInstance(8, 0, 0, 0),
    ThursdayEndTime__c   = Time.newInstance(18, 0, 0, 0),

    // Friday
    FridayStartTime__c = Time.newInstance(8, 0, 0, 0),
    FridayEndTime__c   = Time.newInstance(18, 0, 0, 0),

    // Saturday
    SaturdayStartTime__c = Time.newInstance(8, 0, 0, 0),
    SaturdayEndTime__c   = Time.newInstance(18, 0, 0, 0),

    // Sunday
    SundayStartTime__c = Time.newInstance(8, 0, 0, 0),
    SundayEndTime__c   = Time.newInstance(18, 0, 0, 0)
);
insert au;

AssignmentUser__c au1 = new AssignmentUser__c(
    User__c = testUser.Id,
    AssignmentRule__c = asr2.Id,
    IsActive__c = true,
    Current_Load__c = 1,
    MaximumCapacity__c = 15,

    MondayStartTime__c = Time.newInstance(8, 0, 0, 0),
    MondayEndTime__c   = Time.newInstance(18, 0, 0, 0),
    TuesdayStartTime__c = Time.newInstance(8, 0, 0, 0),
    TuesdayEndTime__c   = Time.newInstance(18, 0, 0, 0),
    WednesdayStartTime__c = Time.newInstance(8, 0, 0, 0),
    WednesdayEndTime__c   = Time.newInstance(18, 0, 0, 0),
    ThursdayStartTime__c = Time.newInstance(8, 0, 0, 0),
    ThursdayEndTime__c   = Time.newInstance(18, 0, 0, 0),
    FridayStartTime__c = Time.newInstance(8, 0, 0, 0),
    FridayEndTime__c   = Time.newInstance(18, 0, 0, 0),
    SaturdayStartTime__c = Time.newInstance(8, 0, 0, 0),
    SaturdayEndTime__c   = Time.newInstance(18, 0, 0, 0),
    SundayStartTime__c = Time.newInstance(8, 0, 0, 0),
    SundayEndTime__c   = Time.newInstance(18, 0, 0, 0)
);
insert au1;

        
       
        
        // Create Service Requests with additional required fields
        ServiceRequest__c srAdm = new ServiceRequest__c(
            RecordTypeId = admrRecordTypeId,
            SalesOrder__c = so.Id,
            Status__c = 'New',            
            Transferred_Sales_Order__c = businessSO.Id
        );
        
        insert srAdm;
            
    
     ServiceRequest__c srAdm1 = new ServiceRequest__c(
            RecordTypeId = unitswapRecordTypeId,
            SalesOrder__c = so.id,
            Status__c = 'New'  
        );
        insert srAdm1;
    }
    @isTest
    static void myUnitTest() {
        ServiceRequest__c thisRequest = [SELECT Id, SalesOrder__c,UnitId__c FROM ServiceRequest__c LIMIT 1];
       
        Test.startTest();
        ADM_SR_Assignment.Today ='Monday';
        ADM_SR_Assignment.assignServiceRequests(new List<ServiceRequest__c> {thisRequest});
        ADM_SR_Assignment.assignServiceRequestsCMTeam(new List<ServiceRequest__c> {thisRequest},'Plot Handover','CM Team SR Test');
        ADM_SR_Assignment.Today ='Tuesday';
        ADM_SR_Assignment.assignServiceRequests(new List<ServiceRequest__c> {thisRequest});
        ADM_SR_Assignment.assignServiceRequestsCMTeam(new List<ServiceRequest__c> {thisRequest},'Plot Handover','CM Team SR Test');
        Test.stopTest();
        List<ServiceRequest__c> updatedSRs = [
            SELECT Id, OwnerId, Status__c
            FROM ServiceRequest__c
            WHERE Id = :thisRequest.Id
        ];
        System.assertEquals(1, updatedSRs.size(), 'There should be one updated Service Request');
    }
    @isTest
    static void myUnitTestforWtoS() {
        ServiceRequest__c thisRequest = [SELECT Id, SalesOrder__c,UnitId__c FROM ServiceRequest__c LIMIT 1];
      
        Test.startTest();
        ADM_SR_Assignment.Today ='Wednesday';
        ADM_SR_Assignment.assignServiceRequests(new List<ServiceRequest__c> {thisRequest});
      ADM_SR_Assignment.assignServiceRequestsCMTeam(new List<ServiceRequest__c> {thisRequest},'Plot Handover','CM Team SR Test');
        ADM_SR_Assignment.Today ='Thursday';
        ADM_SR_Assignment.assignServiceRequests(new List<ServiceRequest__c> {thisRequest});
       ADM_SR_Assignment.assignServiceRequestsCMTeam(new List<ServiceRequest__c> {thisRequest},'Plot Handover','CM Team SR Test');
        ADM_SR_Assignment.Today ='Firday';
        ADM_SR_Assignment.assignServiceRequests(new List<ServiceRequest__c> {thisRequest});
        ADM_SR_Assignment.assignServiceRequestsCMTeam(new List<ServiceRequest__c> {thisRequest},'Plot Handover','CM Team SR Test');
        ADM_SR_Assignment.Today ='Saturday';
        ADM_SR_Assignment.assignServiceRequests(new List<ServiceRequest__c> {thisRequest});
       ADM_SR_Assignment.assignServiceRequestsCMTeam(new List<ServiceRequest__c> {thisRequest},'Plot Handover','CM Team SR Test');
        Test.stopTest();
        List<ServiceRequest__c> updatedSRs = [
            SELECT Id, OwnerId, Status__c
            FROM ServiceRequest__c
            WHERE Id = :thisRequest.Id
        ];
        System.assertEquals(1, updatedSRs.size(), 'There should be one updated Service Request');
    }
    @isTest
    static void myUnitTestSunday() {
        ServiceRequest__c thisRequest = [SELECT Id, SalesOrder__c,UnitId__c FROM ServiceRequest__c LIMIT 1];
       
        Test.startTest();
        ADM_SR_Assignment.Today ='Sunday';
        ADM_SR_Assignment.assignServiceRequests(new List<ServiceRequest__c> {thisRequest});  
               ADM_SR_Assignment.assignServiceRequestsCMTeam(new List<ServiceRequest__c> {thisRequest},'Plot Handover','CM Team SR Test');

        Test.stopTest();
        List<ServiceRequest__c> updatedSRs = [
            SELECT Id, OwnerId, Status__c
            FROM ServiceRequest__c
            WHERE Id = :thisRequest.Id
        ];
        System.assertEquals(1, updatedSRs.size(), 'There should be one updated Service Request');
    }
    
    @isTest
static void testAssignServiceRequestsCMTeam_UserAssignment() {
    // Query any existing queue
    Group cmQueue = [
        SELECT Id, DeveloperName 
        FROM Group 
        WHERE Type = 'Queue' 
        LIMIT 1
    ];

    // Create active Assignment Rule
    AssignmentRule__c asr = new AssignmentRule__c(
        IsActive__c = true,
        Recordtype__c = 'Service Request',
        ProcessName__c = 'Plot Handover',
        ProcessType__c = 'Sales',
        DefaultQueueID__c = cmQueue.Id
    );
    insert asr;

    // Create AssignmentUser linked to the rule
    AssignmentUser__c aUser = new AssignmentUser__c(
        User__c = UserInfo.getUserId(),
        AssignmentRule__c = asr.Id,
        IsActive__c = true,
        Current_Load__c = 0
    );
    insert aUser;

           ServiceRequest__c thisRequest = [SELECT Id, SalesOrder__c FROM ServiceRequest__c LIMIT 1];


    Test.startTest();
    ADM_SR_Assignment.assignServiceRequestsCMTeam(
       new List<ServiceRequest__c> {thisRequest},
        'Plot Handover',
        cmQueue.DeveloperName
    );
    Test.stopTest();

   }

    
}