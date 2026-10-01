@isTest
public class GenericTaskController_Test {

    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Flow_Test',
            Type__c = 'Cost Approval'
        );
        insert pf;

        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;

        Milestone__c ms = new Milestone__c(
            Name = 'MS',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today()
        );
        insert ms;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Milestone__c = ms.Id
        );
        insert bp;
        Id rtId = Schema.SObjectType.Task
    .getRecordTypeInfosByDeveloperName()
    .get('General_Task')
    .getRecordTypeId();

        Task t = new Task(
            Subject = 'Call Attempt 1',
            WhatId = bp.Id,
            Status = 'Open',
            Priority = 'Normal',
            recordTypeId=rtId,
            NextTaskMilestone__c = 1
        );
        insert t;
    }

    @isTest
    static void testGetPicklistValues() {

        Test.startTest();
        List<String> vals = GenericTaskController.getPicklistValues('Task', 'Status');
        Test.stopTest();
        
    }

    @isTest
    static void testSaveCallTask_CustomerSolution() {

        Task t = [SELECT Id FROM Task LIMIT 1];
        Business_Process__c bp=[Select Id from Business_Process__c LIMIT 1];

        Task input = new Task(
            Id = t.Id,
            WhatId=bp.Id,
            Status = 'Customer Solution',
            Description = 'Updated',
            D_T_Customer_Discussion_Outcome__c = 'Consolidation'
        );

        Test.startTest();
        GenericTaskController.saveCallTask(input);
        Test.stopTest();
        //GenericTaskController.updateBusinessProcessFromTask(input);
    }

    @isTest
    static void testSaveCallTask_ContactedBranch() {

        Task t = [SELECT Id FROM Task LIMIT 1];

        Task input = new Task(
            Id = t.Id,
            Status = 'Contacted',
            Description = 'Updated'
        );

        Test.startTest();
        GenericTaskController.saveCallTask(input);
        Test.stopTest();
    }

    @isTest
    static void testSaveCallTask_NextTaskCreation() {

        Task t = [SELECT Id, Subject FROM Task LIMIT 1];

        Task input = new Task(
            Id = t.Id,
            Status = 'Customer Not Reachable',
            Description = 'Updated'
        );

        Test.startTest();
        GenericTaskController.saveCallTask(input);
        Test.stopTest();
    }

    @isTest
    static void testCreateNextTask() {

        Task t = [
            SELECT Id, Subject, WhatId, Priority, NextTaskMilestone__c
            FROM Task LIMIT 1
        ];

        Id rtId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('General_Task')
            .getRecordTypeId();

        Test.startTest();
        Task nextT = GenericTaskController.createNextTask(t, rtId);
        Test.stopTest();
    }

    @isTest
    static void testGetTaskScreenData() {

        Task t = [SELECT WhatId FROM Task LIMIT 1];

        Test.startTest();
        GenericTaskController.TaskScreenWrapper wrap =
            GenericTaskController.getTaskScreenData(t.WhatId);
        Test.stopTest();
    }
}