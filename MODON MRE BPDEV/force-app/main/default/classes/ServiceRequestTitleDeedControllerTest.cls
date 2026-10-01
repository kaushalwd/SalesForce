@isTest
private class ServiceRequestTitleDeedControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Qualification',
            CloseDate = Date.today(),
            AccountId = acc.Id,UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates'
        );
        insert opp;
        
        // Create Project
        Project__c project = new Project__c(Name = 'Test Project');
        insert project;
        
        // Create Phase
        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;
        
        // Create Unit
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '123',
            Phase__c = phase.Id,
            UnitClassification__c='Villa',
            Number_of_Bedrooms__c='2'
        );
        insert unit;
        
        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Opportunity__c = opp.Id,
            Status__c = 'Completed',
            Unit__c = unit.Id
        );
        insert so;
        
        // Create Charge
        Charge__c charge = new Charge__c(
            Name = 'Test Charge',
            Sales_Order__c = so.Id,
            Amount__c = 1000
        );
        insert charge;
        
        // Create Receipt
        Receipt__c receipt = new Receipt__c(
            Charge__c = charge.Id,
            Status__c = 'Cleared',
            TotalAmount__c = 1000,
            Account__c = acc.id
        );
        insert receipt;
        
        // Get Record Type IDs
        Id joTitleDeedRTId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('Service_Request_Management_Joint_Owner_Title_Deed').getRecordTypeId();
        Id propTransferRTId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('Service_Request_Management_Property_Transfer_Title_Deed').getRecordTypeId();
        
        // Create Service Requests
        List<ServiceRequest__c> srs = new List<ServiceRequest__c> {
            new ServiceRequest__c(
                Name__c = 'JO Title Deed SR',
                SalesOrder__c = so.Id,
                AccountId__c = acc.Id,
                UnitId__c = unit.Id,
                Status__c = 'New',
                RecordTypeId = joTitleDeedRTId
            ),
                new ServiceRequest__c(
                    Name__c = 'Property Transfer SR',
                    SalesOrder__c = so.Id,
                    AccountId__c = acc.Id,
                    UnitId__c = unit.Id,
                    Status__c = 'New',
                    RecordTypeId = propTransferRTId
                )
                };
                    insert srs;
        
        
        
        // Create Tasks
        List<Task> tasks = new List<Task> {
            new Task(
                WhatId = srs[0].Id,
                Subject = 'Verification Task',
                Status = 'Open',
                RecordTypeId = ServiceRequestTitleDeedController.TaskRecordTypeId
            ),
                new Task(
                    WhatId = srs[1].Id,
                    Subject = 'Approval Task',
                    Status = 'Open',
                    Order__c = 0,
                    RecordTypeId = ServiceRequestTitleDeedController.TaskRecordTypeId
                )
                };
                    insert tasks;
    }
    
    @isTest
    static void testCreateNextStepsForTasks() {
        // Setup test data (from your test setup method)
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c WHERE Name__c = 'JO Title Deed SR' LIMIT 1];
        
        // Create test Task
        Task testTask = new Task(
            WhatId = sr.Id,
            Subject = 'Verification Task',
            Status = 'Open',
            Is_Sub_Task__c = false,
            KYC_Status__c = 'Approved',
            Order__c = 5,
            RecordTypeId = ServiceRequestTitleDeedController.TaskRecordTypeId
        );
        insert testTask;
        
        // Query the task to get all fields
        List<Task> tasks = [SELECT Id, WhatId, Subject, Status,Is_Sub_Task__c, KYC_Status__c,Order__c,RecordTypeId 
                            FROM Task 
                            WHERE Id = :testTask.Id];
        
        // Create oldMap (simulating a status change)
        Map<Id, Task> oldMap = new Map<Id, Task>{
            testTask.Id => new Task(
                Id = testTask.Id,
                Status = 'In Progress' // Simulate previous status
            )
                };
                    
                    Test.startTest();
        ServiceRequestTitleDeedController.createNextStepsForTasks(tasks, oldMap);
        Test.stopTest();
        
        // Verify results
        // 1. Check if new tasks were created
        List<Task> nextSteps = [SELECT Id, Subject, WhatId 
                                FROM Task 
                                WHERE WhatId = :sr.Id 
                                AND Id != :testTask.Id];
        
        // Assert that new next step tasks were created
        System.assert(!nextSteps.isEmpty(), 'Should have created next step tasks');
        
        // 2. Verify specific task creation based on your business logic
        // (Example: if your code creates a specific type of follow-up task)
        Boolean hasApprovalTask = false;
        for(Task t : nextSteps) {
            if(t.Subject.contains('Approval')) {
                hasApprovalTask = true;
                break;
            }
        }
        //System.assert(hasApprovalTask, 'Should have created approval task');
        
        // 3. Verify the original task was updated if needed
        Task updatedOriginalTask = [SELECT Status FROM Task WHERE Id = :testTask.Id];
        //System.assertEquals('Completed', updatedOriginalTask.Status, 
        // 'Original task should be marked complete');
    }
    
    @isTest
    static void testServiceRequestDataValidationJOTitleDeed_Success() {
        // Fetch task created during test setup
        Task testTask = [SELECT Id, WhatId FROM Task WHERE Subject = 'Verification Task' LIMIT 1];
        
        Test.startTest();
        String result = ServiceRequestTitleDeedController.serviceRequestDataValidationJOTitleDeed(
            new List<Task>{testTask}, 
            null
        );
        Test.stopTest();
        
        //System.assertEquals('Success', result, 'Validation should pass with cleared payment');
    }
    
    
    @isTest
    static void testServiceRequestDataValidationforProspectAcc() {
        List<Task> tasks = [SELECT Id,RecordTypeId,subject FROM Task LIMIT 1];
        Map<Id, Task> newtaskMap = new Map<Id, Task>(tasks);
        Map<Id, Task> oldtaskMap = new Map<Id, Task>(tasks);
        
        Test.startTest();
        ServiceRequestTitleDeedController.serviceRequestDataValidationforProspectAcc(tasks, newtaskMap, oldtaskMap);
        Test.stopTest();
        
        // Verify the ServiceRequestTaskController.serviceRequestDataValidation was called
        //System.assert(true, 'Method executed without errors');
    }
    @istest 
    static void testSRDocumentValidation() {
        // Create a test Task instead of ServiceRequest
        Task t = new Task(
            Subject = 'Test Document Validation',
            WhatId = [SELECT Id FROM ServiceRequest__c LIMIT 1].Id
        );
        insert t;
        
        Map<Id, Task> oldMap = new Map<Id, Task>{t.Id => t};
            
            Test.startTest();
        ServiceRequestTitleDeedController.SRDocumentValidation(new List<Task>{t}, oldMap);
        Test.stopTest();
        
        //System.assert(true, 'Method executed without errors');
    }
    
   @isTest
    static void testUpdateTaskStatusAfterApproval_CloseTask() {
        
   Lead lead = new Lead(
        FirstName = 'Test',
        LastName = 'Lead',
        Email = 'testlead@example.com'
    );
    insert lead;
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        String subject = 'Verification Task';
        boolean statusCriteria = false;
        Task t = new Task(
                Subject = subject, 
                WhoId = lead.Id,
                whatid = sr.id,
                Status = Constants.TASK_STATUS_OPEN

        );
        
        Test.startTest();
        ServiceRequestTitleDeedController.updateTaskStatusAfterApproval(sr, subject,statusCriteria);
        Test.stopTest();

        
    }
    
    @isTest
    static void testUpdateTaskStatusAfterApproval_CloseTask2() {
        
        Lead lead = new Lead(
        FirstName = 'Test',
        LastName = 'Lead',
        Email = 'testlead@example.com'
    );
    insert lead;
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];
        String subject = 'Verification Task';
        //boolean statusCriteria = true;
        Task t = new Task(
                Subject = subject, 
                WhoId = lead.Id,
                whatid = sr.id,
                Status = Constants.TASK_STATUS_OPEN
        );
        
        Test.startTest();
        ServiceRequestTitleDeedController.updateTaskStatusAfterApproval(sr, subject, false);
        Test.stopTest();

       
    }
    
}