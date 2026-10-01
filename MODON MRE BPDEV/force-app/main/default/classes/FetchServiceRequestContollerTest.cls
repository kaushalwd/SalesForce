@isTest
public class FetchServiceRequestContollerTest {
    private static final string SERVICE_REQUEST_RT_DEV_NAME_ADM { get { return 'Service_Request_Management_ADM'; } }
  @isTest  
    static void testGetCaseObjData() {
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id caseId = testData.get('TestCase');
        Id ownerId = testData.get('UserPragathi');
        // Test the method
        Test.startTest();
        List<Case> caseData = FetchServiceRequestContoller.getCaseObjData(caseId);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateCaseWithServiceRequest() {
        // Retrieve test case
        Map<String, Id> testCased = TestDataFactory.createTestData();
        Id caseId = testCased.get('TestCasedata');
        
        Case testCaseda = [SELECT Id FROM Case LIMIT 1];
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
                        Test.startTest();
        ServiceRequest__c sr = TestDataFactory.createServiceRequest('Normal',admrRecordTypeId);

        testCaseda.SR_Number__c=sr.Name;
        update testCaseda;
        // Test the method
        FetchServiceRequestContoller.updateCaseWithServiceRequest(testCaseda.Id, sr.Id);
                Test.stopTest();

        // Verify the update
        Case updatedCase = [SELECT SR_Number__c FROM Case WHERE Id = :testCaseda.Id];
    }
    
    @isTest
    static void testGetSalesOrders() {
        // Retrieve test unit
        SalesOrder__c so=TestDataFactory.createsalesOrder();
        SalesOrder__c testSalesOrder = [SELECT Id, Unit__c FROM SalesOrder__c LIMIT 1];
        testSalesOrder.Unit__c=null;
        update testSalesOrder;
        // Test the method
        Test.startTest();
        List<SalesOrder__c> salesOrders = FetchServiceRequestContoller.getSalesOrders(testSalesOrder.Unit__c);
        Test.stopTest();
    }
    
    @isTest
    static void testGetSalesOrderswithUnit() {
        // Retrieve test unit
        Unit__c u=TestDataFactory.createunit();
        
        SalesOrder__c soobj=TestDataFactory.createsalesOrder();
        soobj.Unit__c=u.id;
        update soobj;
        SalesOrder__c testSalesOrders = [SELECT Id, Unit__c FROM SalesOrder__c LIMIT 1];
        
        // Test the method
        Test.startTest();
        List<SalesOrder__c> salesOrders = FetchServiceRequestContoller.getSalesOrders(testSalesOrders.Unit__c);
        Test.stopTest();
   }
    
    /*@isTest
    static void testUpdateCaseWithServiceRequest_Exception() {
        Test.startTest();
        
        // Step 1: Create valid Case & ServiceRequest records
        Map<String, Id> testCased = TestDataFactory.createTestData();
        Id caseId = testCased.get('TestCasedata');
        
        Case testCaseda = [SELECT Id FROM Case LIMIT 1];
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        
        ServiceRequest__c testServiceRequest = TestDataFactory.createServiceRequest('Normal',admrRecordTypeId);
        
        // Step 2: Delete one of the records to force an exception
        delete testServiceRequest;
        
        Boolean exceptionThrown = false;
        
        try {
            // Step 3: Call method with deleted ServiceRequest ID (causes exception)
            FetchServiceRequestContoller.updateCaseWithServiceRequest(testCaseda.id, testServiceRequest.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        
        Test.stopTest();
        
        // Step 4: Validate that an exception was thrown
    }*/
    
}