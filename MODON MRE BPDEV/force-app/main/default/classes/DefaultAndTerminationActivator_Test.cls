@isTest
public class DefaultAndTerminationActivator_Test {

    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Termination Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Termination_Flow_Test',
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
            Milestone__c = ms.Id,
            CRM_Manager_decision__c='Proceed without default notification',
            D_T_Customer_Discussion_Outcome__c = 'Escalate for further action'
        );
        insert bp;

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Manager Default Notice Approval',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'S1',
            Business_Process_Steps_Name_Custom__c = 'S1',
            Process_Flow_Step__c = pfs.Id,
            Skip_Step_To_Reopen__c = false
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Collections Customer Engagement',
            Status__c = 'Required Info',
            Business_Process__c = bp.Id,
            Sequence__c = 2,
            Section_Number__c = 1,
            section_Name__c = 'S2',
            Business_Process_Steps_Name_Custom__c = 'S2',
            Process_Flow_Step__c = pfs.Id,
            Skip_Step_To_Reopen__c = true,
            Re_Open_Count__c = 1,
            Assigned_To__c=UserInfo.getUserId()
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 3',
            Status__c = 'Accepted',
            Business_Process__c = bp.Id,
            Sequence__c = 3,
            Assigned_To__c = UserInfo.getUserId(),
            Section_Number__c = 1,
            section_Name__c = 'S3',
            Business_Process_Steps_Name_Custom__c = 'S3',
            Process_Flow_Step__c = pfs.Id,
            Skip_Step_To_Reopen__c = false
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 4',
            Status__c = 'Open',
            Business_Process__c = bp.Id,
            Sequence__c = 4,
            Section_Number__c = 1,
            section_Name__c = 'S4',
            Business_Process_Steps_Name_Custom__c = 'S4',
            Process_Flow_Step__c = pfs.Id,
            Skip_Step_To_Reopen__c = false
        ));

        insert steps;
    }

    @isTest
    static void testRequiredInfoBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Skip_Step_To_Reopen__c,
                   Business_Process__c,
                  Is_Process_End__c,
            Business_Process__r.CRM_Manager_decision__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c prev = steps[0];
        prev.Required_Info_Step__c = steps[1].Id;

        Test.startTest();

        new DefaultAndTerminationActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testEscalationPath_NumEquals2() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Skip_Step_To_Reopen__c,
                   Business_Process__c,
                   Business_Process__r.D_T_Customer_Discussion_Outcome__c,
                   Is_Process_End__c,
            Business_Process__r.CRM_Manager_decision__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new DefaultAndTerminationActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testSkipStepIncrementBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Skip_Step_To_Reopen__c,
                   Business_Process__c,
                   Business_Process__r.CRM_Manager_decision__c,
            Is_Process_End__c
                   
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Skip_Step_To_Reopen__c = true;
        steps[1].Re_Open_Count__c = 1;

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new DefaultAndTerminationActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testAssignedAndReopenBranches() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Skip_Step_To_Reopen__c,
                   Business_Process__c,
                   Is_Process_End__c,
            Business_Process__r.CRM_Manager_decision__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c = UserInfo.getUserId();
        steps[1].Re_Open_Count__c = 1;

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new DefaultAndTerminationActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testOpenBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Skip_Step_To_Reopen__c,
                   Business_Process__c,
                   Is_Process_End__c,
            Business_Process__r.CRM_Manager_decision__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c =null;
        steps[1].Re_Open_Count__c = 0;
        steps[1].Status__c = 'New';
        steps[1].Name='Collections Customer Negotiations';
       
        steps[0].Name='Default 1 Notice Approval';
        steps[0].Assigned_To__c =UserInfo.getUserId();
        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new DefaultAndTerminationActivator().activateNextSteps(
            prev.Id,
            steps,	
            prev,
            null
        );

        Test.stopTest();
    }
    
    @isTest
    static void testOpenBranch2() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Skip_Step_To_Reopen__c,
                   Business_Process__c,
                   Is_Process_End__c,
            Business_Process__r.CRM_Manager_decision__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c =null;
        steps[1].Re_Open_Count__c = 0;
        steps[1].Status__c = 'New';
        steps[1].Name='Senior Manager Default Notice Approval';
       
        steps[0].Name='Default 1 Notice Approval';
        steps[0].Assigned_To__c =UserInfo.getUserId();
        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new DefaultAndTerminationActivator().activateNextSteps(
            prev.Id,
            steps,	
            prev,
            null
        );

        Test.stopTest();
    }
   
        @isTest
    static void testOpenBranch3() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Skip_Step_To_Reopen__c,
                   Business_Process__c,
                   Is_Process_End__c,
            Business_Process__r.CRM_Manager_decision__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c =null;
        steps[1].Re_Open_Count__c = 1;
        steps[1].Status__c = 'Open';
        steps[1].Name='Senior Manager Default Notice Approval1';
         update steps;
        steps[0].Name='step1';
        steps[0].Assigned_To__c =UserInfo.getUserId();
        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new DefaultAndTerminationActivator().activateNextSteps(
            prev.Id,
            steps,	
            prev,
            null
        );

        Test.stopTest();
    }
    
}