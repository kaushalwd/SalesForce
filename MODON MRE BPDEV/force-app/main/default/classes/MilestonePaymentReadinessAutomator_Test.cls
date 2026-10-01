@isTest
public class MilestonePaymentReadinessAutomator_Test {

    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Milestone Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Milestone_Readiness_Auto',
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

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
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
            Name = 'DLD Completion with Payment',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Section A',
            Business_Process_Steps_Name_Custom__c = 'DLD Payment Step',
            Process_Flow_Step__c = pfs.Id
        );
        insert step;
    }

    @isTest
    static void testExecuteAutomation_CompletedStep() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c,
                   Section_Number__c,
                   section_Name__c,
                   Business_Process_Steps_Name_Custom__c
            FROM Business_Process_Step__c
        ];

        BusinessProcessAutomationInput inputObj = new BusinessProcessAutomationInput();
        inputObj.steps = steps;

        Test.startTest();

        new MilestonePaymentReadinessAutomator().executeAutomation(inputObj);

        Test.stopTest();
    }

    @isTest
    static void testExecuteAutomation_NonMatchingStep() {

        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Other Step',
            Status__c = 'Completed',
            Business_Process__c = [SELECT Id FROM Business_Process__c LIMIT 1].Id,
            Sequence__c = 2,
            Section_Number__c = 1,
            section_Name__c = 'Section B',
            Business_Process_Steps_Name_Custom__c = 'Other',
            Process_Flow_Step__c =[Select Id from Process_Flow_Step__c LIMIT 1].Id
        );
        insert step;

        BusinessProcessAutomationInput inputObj = new BusinessProcessAutomationInput();
        inputObj.steps = new List<Business_Process_Step__c>{ step };

        Test.startTest();

        new MilestonePaymentReadinessAutomator().executeAutomation(inputObj);

        Test.stopTest();
    }

    @isTest
    static void testExecuteAutomation_NotCompleted() {

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c,
                   Section_Number__c,
                   section_Name__c,
                   Business_Process_Steps_Name_Custom__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        step.Status__c = 'Accepted';
        update step;

        BusinessProcessAutomationInput inputObj = new BusinessProcessAutomationInput();
        inputObj.steps = new List<Business_Process_Step__c>{ step };

        Test.startTest();

        new MilestonePaymentReadinessAutomator().executeAutomation(inputObj);

        Test.stopTest();
    }
}