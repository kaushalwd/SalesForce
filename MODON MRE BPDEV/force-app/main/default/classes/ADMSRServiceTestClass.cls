@isTest
public class ADMSRServiceTestClass {
        private static final String SERVICE_REQUEST_RT_DEV_NAME_ADM = 'Service_Request_Management_ADM';

        private static String  admrRecordTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get(SERVICE_REQUEST_RT_DEV_NAME_ADM).getRecordTypeId();

    @testSetup
    static void setupData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        // Create Opportunity
        Opportunity opp = new Opportunity();
        opp.Name = 'Test opportunity';
        opp.StageName = 'Discussion In Progress';
        opp.CloseDate = System.Today();
        opp.UAE_Resident_Status__c = 'Resident';
		opp.Nationality__c = 'United Arab Emirates';
		opp.EmiratesIDExpiryDate__c = Date.today().addDays(365);
		opp.EIDNumber__c='784-1232-1234567-4';
        INSERT opp;
        
Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
        insert unit;

         Unit__c unit1 = new Unit__c();
        unit1.Phase__c = phase.Id;
        unit1.PlotAreasqm__c = 1.0;
        unit1.PlotNo__c = '1';
        unit1.UnitClassification__c = 'Villa';
        unit1.Number_of_Bedrooms__c = '1';
        insert unit1;

         Unit__c unit2 = new Unit__c();
        unit2.Phase__c = phase.Id;
        unit2.PlotAreasqm__c = 1.0;
        unit2.PlotNo__c = '1';
        unit2.UnitClassification__c = 'Villa';
        unit2.Number_of_Bedrooms__c = '1';
        insert unit2;
        
        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'Completed',
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            Opportunity__c = opp.Id
        );
        insert so;
         SalesOrder__c so1 = new SalesOrder__c(
            Status__c = 'Completed',
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            Opportunity__c = opp.Id
        );
        insert so1;
         SalesOrder__c so2 = new SalesOrder__c(
            Status__c = 'Completed',
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            Opportunity__c = opp.Id
        );
        insert so2;
        
        ServiceRequest__c srAdm = new ServiceRequest__c(
            RecordTypeId = admrRecordTypeId,
            SalesOrder__c = so.Id,
            Status__c = 'New'           
        );
        
        
        insert srAdm;
        
         ServiceRequest__c srAdm1 = new ServiceRequest__c(
            RecordTypeId = admrRecordTypeId,
            Transferred_Sales_Order__c = so1.Id,
             SalesOrder__c = so2.id,
            Status__c = 'New'           
        );
        
        
        insert srAdm1;
        
    AssignmentRule__c asr = new AssignmentRule__c(
            IsActive__c = true,
            Recordtype__C = 'service Request',
            ProcessName__c = 'ADM',
            ProcessType__c = 'Sales'
        );
        insert asr;        
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
        
        // Insert AssignmentUser__c
        AssignmentUser__c au = new AssignmentUser__c(
            User__c = testUser.Id,
            AssignmentRule__c = asr.Id,
            IsActive__c = true,
            Current_Load__c = 1,
            MaximumCapacity__c = 15,
            MondayStartTime__c = Time.newInstance(8, 0, 0, 0),
            MondayEndTime__c = Time.newInstance(18, 0, 0, 0)
        );
        insert au;
        



    }
    
    
    @isTest
    static void testCreateADMServiceRequests_NewSR() {
        // Fetch data
        SalesOrder__c newSo = new SalesOrder__c(
            Status__c = 'Completed',
            CustomerAccount__c = [SELECT Id FROM Account LIMIT 1].Id,
            Unit__c = [SELECT Id FROM Unit__c LIMIT 1].Id,
            Opportunity__c = [SELECT Id FROM Opportunity LIMIT 1].Id
        );
        Test.startTest();
        insert newSo;
        
        
        ADMSRService.createADMServiceRequests(new List<SalesOrder__c>{ newSo });
        Test.stopTest();
        
        List<ServiceRequest__c> createdSRs = [
            SELECT Id, SalesOrder__c, Name__c
            FROM ServiceRequest__c
            WHERE SalesOrder__c = :newSo.Id
        ];
        
       
    }
    
  
    
    @isTest
    static void testCreateADMServiceRequests_NullOrEmptyList() {
        Test.startTest();
        ADMSRService.createADMServiceRequests(null);
        ADMSRService.createADMServiceRequests(new List<SalesOrder__c>());
        Test.stopTest();
        
        // Should not throw any exception
    }
    @isTest
static void testCreateADMServiceRequests_ForceException() {
    // Create SO with missing required fields in SR (e.g., Unit__c is null or invalid)
    Account acc = new Account(Name = 'Error Test Account');
    Test.startTest();
    insert acc;

    SalesOrder__c errorSO = new SalesOrder__c(
        Status__c = 'Completed',
        CustomerAccount__c = acc.Id,
        Unit__c = null, // Will cause ServiceRequest insert to fail if UnitId__c is required
        Opportunity__c = null // Missing field
    );
    
    insert errorSO;

    
    ADMSRService.createADMServiceRequests(new List<SalesOrder__c>{ errorSO });
    Test.stopTest();

}
    @isTest
static void testExistingSOWithSRLogicCoverage() {
    List<SalesOrder__c> sos = [
        SELECT Id FROM SalesOrder__c WHERE Status__c = 'Completed' LIMIT 2
    ];
    
    Test.startTest();
    ADMSRService.createADMServiceRequests(sos);
    Test.stopTest();
}

    
    
}