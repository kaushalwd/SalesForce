@isTest
public class DefaultAndTerminationValidator_Test {

    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Default Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Default_Flow_Test',
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
            Name = 'Collections Customer Engagement',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 1,
            Process_Flow_Step__c = pfs.Id,
            Business_Process_Steps_Name_Custom__c = 'Engagement',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        );
        insert step;
    }

    @isTest
    static void testCollectionsCustomerEngagement_NoTask() {

        Business_Process_Step__c step = [
            SELECT Id, Name, Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        DefaultAndTerminationValidator v = new DefaultAndTerminationValidator();
        v.ValidateSteps(step);

        Test.stopTest();
    }

    @isTest
    static void testCollectionsCustomerNegotiations_NoOutcome() {

        Process_Flow__c pf = [SELECT Id FROM Process_Flow__c LIMIT 1];

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.D_T_Customer_Discussion_Outcome__c = null;
        update bp;

        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Collections Customer Negotiations',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 2,
            Process_Flow_Step__c = [SELECT Id FROM Process_Flow_Step__c LIMIT 1].Id,
            Business_Process_Steps_Name_Custom__c = 'Negotiations',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        );
        insert step;

        Test.startTest();

        try {
            new DefaultAndTerminationValidator().ValidateSteps(step);
        } catch (AuraHandledException e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testCollectionsCustomerNegotiations_TaskOpen() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        bp.D_T_Customer_Discussion_Outcome__c = 'Escalate for further action';
        update bp;

        Task t = new Task(
            Subject = 'Call Task - Default 1  Notice Approval - Default Notice test',
            WhatId = bp.Id,
            Status = 'Open'
        );
        insert t;

        Business_Process_Step__c step = [
            SELECT Id, Name, Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        step.Name = 'Collections Customer Negotiations';

        Test.startTest();

        try {
            new DefaultAndTerminationValidator().ValidateSteps(step);
        } catch (AuraHandledException e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testLegalDiscussions_NoLegalStatus() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        bp.Legal_Status__c = null;
        update bp;

        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Legal Discussions',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 3,
            Process_Flow_Step__c = [SELECT Id FROM Process_Flow_Step__c LIMIT 1].Id,
            Business_Process_Steps_Name_Custom__c = 'Legal',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        );
        insert step;

        Test.startTest();

        try {
            new DefaultAndTerminationValidator().ValidateSteps(step);
        } catch (AuraHandledException e) {
        }

        Test.stopTest();
    }

    @isTest
    static void testWhenElseBranch() {

        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Random Step',
            Status__c = 'Completed'
        );

        Test.startTest();

        new DefaultAndTerminationValidator().ValidateSteps(step);

        Test.stopTest();
    }
}