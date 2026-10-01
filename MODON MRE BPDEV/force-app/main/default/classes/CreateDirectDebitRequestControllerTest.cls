@isTest
public class CreateDirectDebitRequestControllerTest {

    @testSetup
    static void setupData() {
        // Create Project
        Project__c project = new Project__c(Name = 'Muheira');
        insert project;

        // Create Phase
        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = project.Id);
        insert phase;

        // Create Unit
        Unit__c unit = new Unit__c(Name = 'Unit-101', Phase__c = phase.Id, PlotNo__c = 'P-101', UnitClassification__c ='Apartment', Number_of_Bedrooms__c ='2');
        insert unit;

        // Create Person Account
        Id personAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(
            FirstName = 'John',
            LastName = 'Doe',
            RecordTypeId = personAccountRTId,
            PersonMobilePhone = '971500000001'
        );
        insert acc;

        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id
        );
        insert so;
        
       // Check if the queue already exists
        Group existingQueue = [SELECT Id FROM Group WHERE DeveloperName = 'DirectDebitQueue' AND Type = 'Queue' LIMIT 1];
        
        Id queueId;
        if (existingQueue != null) {
            queueId = existingQueue.Id;
        } else {
            Group queue = new Group(
                Name = 'DirectDebitQueue',
                Type = 'Queue',
                DeveloperName = 'DirectDebitQueue'
            );
            insert queue;
            queueId = queue.Id;
}

// Add current user to the queue if not already added
List<GroupMember> existingMembers = [SELECT Id FROM GroupMember WHERE GroupId = :queueId AND UserOrGroupId = :UserInfo.getUserId()];
if (existingMembers.isEmpty()) {
    GroupMember gm = new GroupMember(
        GroupId = queueId,
        UserOrGroupId = UserInfo.getUserId()
    );
    insert gm;
}

    }

    @isTest
    static void testGetSalesOrderAccDetails_NoExistingDDRequest() {
        // Get test Sales Order
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        CreateDirectDebitRequestController.ResponseWrapper response = 
            CreateDirectDebitRequestController.getSalesOrderAccDetails(so.Id);
        Test.stopTest();

        System.assertNotEquals(null, response, 'ResponseWrapper should not be null');
        System.assertNotEquals(null, response.salesOrderRecord, 'SalesOrder__c should be returned');
        System.assertEquals(so.Id, response.salesOrderRecord.Id, 'SalesOrder Id should match');
    }

    @isTest
    static void testGetSalesOrderAccDetails_WithExistingDDRequest() {
        // Get test Sales Order
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        // Insert existing DirectDebitRequest__c (should cause validation to return true)
        DirectDebitRequest__c ddRequest = new DirectDebitRequest__c(
            SalesOrder__c = so.Id,
            Status__c = 'Finance Team Approved' // Not in Cancelled or Rejected
        );
        insert ddRequest;

        Test.startTest();
        CreateDirectDebitRequestController.ResponseWrapper response = 
            CreateDirectDebitRequestController.getSalesOrderAccDetails(so.Id);
        Test.stopTest();

        // Since DDRequest exists, response.salesOrderRecord should be null
        System.assertNotEquals(null, response, 'ResponseWrapper should not be null');
        System.assertEquals(null, response.salesOrderRecord, 'SalesOrder__c should be null due to existing DDRequest');
    }

    @isTest
    static void testValidateDirectDebitRequestUniqueValidation_PositiveAndNegative() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        // Case 1 - No DDRequest
        Boolean result1 = CreateDirectDebitRequestController.validateDirectDebitRequestUniqueValidation(so.Id);
        System.assertEquals(false, result1, 'No DDRequest yet, should return false');

        // Case 2 - Insert DDRequest
        DirectDebitRequest__c ddRequest = new DirectDebitRequest__c(
            SalesOrder__c = so.Id,
            Status__c = 'Finance Team Approved'
        );
        insert ddRequest;

        Boolean result2 = CreateDirectDebitRequestController.validateDirectDebitRequestUniqueValidation(so.Id);
        System.assertEquals(true, result2, 'Existing DDRequest should return true');
    }

    @isTest
    static void testCreateDirectDebitRequest_EmptyMethod() {
        // This is just to invoke the empty method so it gets 100% coverage
        Test.startTest();
        CreateDirectDebitRequestController.createDirectDebitRequest('{}'); // Dummy JSON
        Test.stopTest();

        // No asserts — just calling for coverage
    }
}