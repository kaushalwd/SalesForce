@isTest
public without sharing class DefaultSRActionController_Test {

    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Flow_Test',
            Type__c = 'Cost Approval'
        );
        insert pf;
         Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Section_Number__c = 1,
            section_Name__c = 'Sec',
            Process_Flow__c = pf.Id
        );
        insert pfs;

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

        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Test Step',
            Business_Process__c = bp.Id,
            Status__c = 'Completed',
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'S1',
            Business_Process_Steps_Name_Custom__c = 'S1',
            Process_Flow_Step__c = pfs.Id
            
        );
        insert step;

        Task t = new Task(
            Subject = 'Old Task',
            Status = 'Open',
            OwnerId = UserInfo.getUserId(),
            WhatId = bp.Id
         
        );
        insert t;
    }

    @isTest
    static void testCreateCallTask_BusinessProcessStep() {

        Business_Process_Step__c step = [
            SELECT Id, Name, Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();
        DefaultSRActionController.createCallTask(
            new List<SObject>{ step },
            'Default Notice1'
        );
        Test.stopTest();
    }

    @isTest
    static void testCreateCallTask_OtherObject() {

        Task t = [
            SELECT Id, OwnerId
            FROM Task
            LIMIT 1
        ];

        Test.startTest();
        DefaultSRActionController.createCallTask(
            new List<SObject>{ t },
            'Default Notice2'
        );
        Test.stopTest();
    }

    @isTest
    static void testCreateCallTask_NoAppendSubject() {

        Task t = [
            SELECT Id, OwnerId
            FROM Task
            LIMIT 1
        ];

        Test.startTest();
        DefaultSRActionController.createCallTask(
            new List<SObject>{ t },
            null
        );
        Test.stopTest();
    }

    @isTest
    static void testSendTaskNotifications() {

        Task t = [
            SELECT Id, Subject, OwnerId, ActivityDate
            FROM Task
            LIMIT 1
        ];

        Test.startTest();
        DefaultSRActionController.sendTaskNotifications(
            new List<Task>{ t },
            null
        );
        Test.stopTest();
    }

    @isTest
    static void testSendTaskNotifications_WithQueue() {

        Task t = [
            SELECT Id, Subject, OwnerId, ActivityDate
            FROM Task
            LIMIT 1
        ];

        Test.startTest();
        DefaultSRActionController.sendTaskNotifications(
            new List<Task>{ t },
            UserInfo.getUserId()
        );
        Test.stopTest();
    }
}