@isTest
public class MilestonePaymentReadActivator_Test {


    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Milestone Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Milestone_Flow_Test',
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

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 1,
            Process_Flow_Step__c = pfs.Id,
             Business_Process_Steps_Name_Custom__c = 'CM',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 2',
            Status__c = 'Required Info',
            Business_Process__c = bp.Id,
            Sequence__c = 2,
            Process_Flow_Step__c = pfs.Id,
             Business_Process_Steps_Name_Custom__c = 'CM',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 3',
            Status__c = 'Accepted',
            Business_Process__c = bp.Id,
            Sequence__c = 3,
            Assigned_To__c = UserInfo.getUserId(),
            Process_Flow_Step__c = pfs.Id,
             Business_Process_Steps_Name_Custom__c = 'CM',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 4',
            Status__c = 'Open',
            Business_Process__c = bp.Id,
            Sequence__c = 4,
            Process_Flow_Step__c = pfs.Id,
             Business_Process_Steps_Name_Custom__c = 'CM',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        ));

        insert steps;
    }

    @isTest
    static void testActivateNextSteps_RequiredInfoBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Business_Process__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c prev = steps[0];
        prev.Required_Info_Step__c = steps[1].Id;

        Test.startTest();

        new MilestonePaymentReadinessActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testActivateNextSteps_RequiredInfoStatusFlow() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Business_Process__c,
                   Required_Info_Step__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new MilestonePaymentReadinessActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testActivateNextSteps_ReOpenBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Business_Process__c,
            Required_Info_Step__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Re_Open_Count__c = 1;

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new MilestonePaymentReadinessActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testActivateNextSteps_AssignedToBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Business_Process__c,
            Required_Info_Step__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c = UserInfo.getUserId();

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new MilestonePaymentReadinessActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testActivateNextSteps_OpenBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Business_Process__c,
            Required_Info_Step__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c = null;
        steps[1].Re_Open_Count__c = 0;
        steps[1].Status__c = 'New';

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new MilestonePaymentReadinessActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }
}