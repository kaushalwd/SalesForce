/**********************************************************************************************************************
* Name               : CaseSLAControllerTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                   Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      	29 Jan 2025     Initial Draft          
* 2.0			ravikumar.pasumarthi@activemindsit.com  29 Dec 2025		Updated test methods
******************************************************************************************************************/
@isTest
public class CaseSLATriggerHelperTest {
    @isTest
    public static void testApproveSLAExtensions() {
        CaseTriggerHandler.isTestRun = true;

        // Fetch the test data IDs
        //Map<String, Id> testData = TestDataFactory.createTestData();

        Case cs = new Case();
        cs.Channel__c = '800 Modon';
        cs.Source__c = '800 Modon';
        cs.CaseType__c = 'Visitor';
        cs.Visitor_First_Name__c = 'test first';
        cs.Visitor_Last_Name__c = 'test last';
        cs.Visitor_Phone__c = '+971556677889';
        insert cs;
            
        Id caseId = cs.Id;//testData.get('TestCase');

        Test.startTest();
        
        CaseSLA__c slaRecord = new CaseSLA__c(
            RunningTestClass__c = true,
            CaseId__c = caseId,
            Extension_Approval__c = null,
            Extension_In_Hours__c = 2,
            Request_Extension__c = true,
            Is_Extension_Allowed__c = true,
            DueTime__c = System.now()
        );
        insert slaRecord;

        slaRecord.Extension_Approval__c = 'Approved'; 
        update slaRecord;

        List<CaseSLA__c> updatedSLAList = [SELECT DueTime__c, Status__c, IsExtended__c, Extension_Approval__c FROM CaseSLA__c WHERE Id = :slaRecord.Id];
        System.assert(updatedSLAList.size() > 0, 'No SLA record found after insert');
        CaseSLA__c updatedSLA = updatedSLAList[0];

        Test.stopTest();
    }
 /*   @isTest
   Public static void testRejectSLAExtensions() {
        
       Map<String, Id> testData = TestDataFactory.createTestData();
       
        Id caseId = testData.get('TestCase');
       
       Test.startTest();
        
        CaseSLA__c slaRecord = new CaseSLA__c(
            CaseId__c = caseId,
            Extension_Approval__c = null,
            Extension_In_Hours__c = 2,
             Is_Extension_Allowed__c = true,
            Request_Extension__c = true
        );
        insert slaRecord;

        slaRecord.Extension_Approval__c = 'Rejected'; 
        update slaRecord;
        
        // Fetch updated SLA record
        CaseSLA__c updatedSLA = [SELECT Request_Extension__c, Extension_Approval__c, Extension_Comments__c, Extension_In_Hours__c FROM CaseSLA__c WHERE Id = :slaRecord.Id];
        //System.assertEquals(false, updatedSLA.Request_Extension__c);
        //System.assertEquals(null, updatedSLA.Extension_Approval__c);
        //System.assertEquals(null, updatedSLA.Extension_Comments__c);
        //System.assertEquals(null, updatedSLA.Extension_In_Hours__c);
       
       Test.stopTest();
    }*/
    
 @isTest
    static void testDeleteMethods() {
        // Setup test data
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id caseId = testData.get('TestCase'); // Fetch a test case from TestDataFactory

        // Start Test
        Test.startTest();
         CaseSLA__c slaRecord = new CaseSLA__c(
            CaseId__c = caseId,
            Extension_Approval__c = null,
            Extension_In_Hours__c = 2,
              Is_Extension_Allowed__c = true,
             Request_Extension__c = true
        );
        Insert slaRecord;
        
        Delete slaRecord;
        
        Test.stopTest();    
    }
    
    @isTest
    static void testUnDeleteMethods() {
        // Setup test data
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id caseId = testData.get('TestCase'); // Fetch a test case from TestDataFactory

        // Start Test
        Test.startTest();
         CaseSLA__c slaRecord = new CaseSLA__c(
            CaseId__c = caseId,
            Extension_Approval__c = null,
            Extension_In_Hours__c = 2,
              Is_Extension_Allowed__c = true,
             Request_Extension__c = true
        );
        Insert slaRecord;
        
        Delete slaRecord;
        
        Undelete slaRecord;
        
        Test.stopTest();    
    }
    
   /* @isTest
    static void testcreateSLAForSR()
    {
        Test.startTest();
        Map<String, Id> ids = TestDataFactory.createTestData();
        Id actId = ids.get('vipOrganizationAccount');
        Id unitId = ids.get('Unit');
        
        Master_SLA__c msla = new Master_SLA__c();
        msla.Name = 'SRM -ADM-KYC Update-Normal';
        msla.IsActive__c = true;
        msla.Milestones__c = 'SRM -ADM-KYC Update-Normal';
        msla.ObjectName__c = 'ServiceRequest__c';
        msla.Case_Origin__c = 'Service Request Management -ADM';
        msla.Category__c = 'General Enquiry';
        msla.Sub_Category__c = 'Office Location/Working Hours';
        msla.SLA_Hrs__c = 2;
        msla.Is_Available_For_Extension__c = true;
        insert msla;
            
        SalesOrder__c so = new SalesOrder__c();
        so.Status__c = 'In Progress';
        so.Unit__c = unitId;
        so.Discount_on_ADM_Fees__c = 0;
        so.ADM_Fees__c = 2;
        so.Daricharges__c = 1234;
        so.CustomerAccount__c = actId;
        insert so;
        
        ServiceRequest__C sr = new ServiceRequest__c();
        List<RecordType> recTypeList = [Select Id from RecordType where SObjectType = 'ServiceRequest__c' and name = 'ADM Registration' limit 1];
        sr.RecordTypeId = recTypeList[0].Id;
        sr.Name__c = 'test SR';
        sr.AccountId__c = actId;
        sr.Type__c = 'Normal';
        sr.SubType__c = 'Normal';
        sr.Description__c = 'sample description';
        sr.SalesOrder__c = so.Id;
        insert sr;
        
        //CaseSLA__c sla = CaseSLATriggerHelper.createSLAForSR(sr);
        Test.stopTest();
	}   */
    
    @isTest
static void testPrepareServiceRequestSLARecord() {
    Test.startTest();
    
    // Create test data
    Map<String, Id> testData = TestDataFactory.createTestData();
    
    // Retrieve necessary IDs
    Id testCaseId = testData.get('TestCase');
    Id salesOrderId = testData.get('SalesOrder');
    Id ownerId = testData.get('modonTestUser');
    Id testAccountId = testData.get('vipOrganizationAccount');
    
    // Create ServiceRequest record
    ServiceRequest__c srRec = new ServiceRequest__c(
        CaseId__c = testCaseId,
        OwnerId = ownerId,
        SalesOrder__c = salesOrderId,
       // SubType__c = 'Next of Kin',
        Status__c = 'New',
        AccountId__c = testAccountId
    );
    insert srRec;
    
    // Create Master SLA record
    Master_SLA__c sla = new Master_SLA__c(
        Name = 'Test SLA',
        SLA_Hrs__c = 24,
        Is_Available_For_Extension__c = true
    );
    insert sla;
    
    // Fetch Business Hours
    BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
    
    // Fetch Holidays (Include ActivityDate to avoid the exception)
    List<Holiday> holidays = [SELECT Id, ActivityDate FROM Holiday];

    // Call method under test
    CaseSLA__c caseSLA = CaseSLATriggerHelper.prepareServiceRequestSLARecord(srRec, sla, bh, holidays);
    
    // Insert CaseSLA record
    insert caseSLA;
    
    caseSLA.Customer_Communication__c = 'Email Sent';
    //caseSLA.Extension_Approval__c = 'Rejected';
    update caseSLA;
    
    // Assertions
    System.assertEquals(srRec.Id, caseSLA.Service_Request__c, 'Service Request should match');
    System.assertEquals(testCaseId, caseSLA.CaseId__c, 'CaseId should match');
    System.assertEquals(ownerId, caseSLA.OwnerId, 'Owner should match');
    System.assertNotEquals(null, caseSLA.StartTime__c, 'Start time should not be null');
    System.assertNotEquals(null, caseSLA.DueTime__c, 'Due time should not be null');
    System.assertEquals(sla.Id, caseSLA.Master_SLA__c, 'Master SLA should match');
    System.assertEquals(ServiceConstants.CaseSLA_STATUS_ONTRACK, caseSLA.Status__c, 'Status should be ON TRACK');
    System.assertEquals(sla.Is_Available_For_Extension__c, caseSLA.Is_Extension_Allowed__c, 'Extension flag should match');
    
    Test.stopTest();
}
    
  /*@isTest
    static void testClearCaseApprovalStatus() {
        // Set up test data
        //Case testCase = new Case(Subject = 'Test Case', Status = 'New', Customer_Email__c= 'rrreddyo411@gmail.com', Requestor_Email__c = 'raghuramgajjela@gmail.com',Approval_Status__c = 'Waiting for Manager Approval');
        //insert testCase;
         Map<String, Id> testData = TestDataFactory.createTestData();
       
        Id caseId = testData.get('TestCase');
        
        CaseSLA__c slaRecord = new CaseSLA__c(CaseId__c = caseId);
        insert slaRecord;

        Test.startTest();
        CaseSLATriggerHelper.clearCaseApprovalStatus(new List<SObject>{slaRecord});
        Test.stopTest();

        Case updatedCase = [SELECT Approval_Status__c FROM Case WHERE Id = :caseId];
        System.assertEquals(null, updatedCase.Approval_Status__c);
    }*/
    
    /*  @isTest
    static void testTriggerHandler_beforeUpdate() {
        
        Unit__c testUnit = new Unit__c(
            Name = 'Test Unit',  
            PlotNo__c = '105'
        );
        insert testUnit;
        
      
        Case testCase = new Case(
            Status = 'New',
            Subject = 'Test Case',
             Requestor_Email__c = 'raghuramgajjela@gmail.com',
            Unit__c = testUnit.Id  
        );
        insert testCase;
        
        
        CaseSLA__c slaRecord = new CaseSLA__c(
            CaseId__c = testCase.Id,
            Extension_Approval__c = null,
            Extension_In_Hours__c = 1,
            DueTime__c = System.now()
        );
        insert slaRecord;
        
       
        slaRecord.Extension_Approval__c = 'Approved'; 
        update slaRecord;
        
        // Validate SLA updates
        CaseSLA__c updatedSLA = [SELECT DueTime__c, Status__c, IsExtended__c FROM CaseSLA__c WHERE Id = :slaRecord.Id];
        System.assertEquals('Extended', updatedSLA.Status__c); 
        System.assert(updatedSLA.DueTime__c != null, 'DueTime__c should not be null');
        System.assertEquals(true, updatedSLA.IsExtended__c);
    }
    
    @isTest
    static void testTriggerHandler_afterInsert() {
        // Set up test data
        Case testCase = new Case(Subject = 'Test Case', Status = 'New', Requestor_Email__c = 'raghuramgajjela@gmail.com', Approval_Status__c = 'Waiting for Manager Approval');
        insert testCase;
        
        CaseSLA__c slaRecord = new CaseSLA__c(CaseId__c = testCase.Id);
        insert slaRecord;
        
        // Validate the after-insert trigger cleared the case approval status
        Case updatedCase = [SELECT Approval_Status__c FROM Case WHERE Id = :testCase.Id];
        System.assertEquals(null, updatedCase.Approval_Status__c);
    }*/
}