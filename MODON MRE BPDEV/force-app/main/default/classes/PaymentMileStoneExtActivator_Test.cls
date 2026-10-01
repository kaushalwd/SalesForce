@isTest
public class PaymentMileStoneExtActivator_Test {

    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Payment Extension Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Payment_Extension_Test',
            Type__c = 'Cost Approval'
        );
        insert pf;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Section_Number__c = 1,
            section_Name__c = 'Validation',
            Process_Flow__c = pf.Id
        );
        insert pfs;

        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
        insert phase;

        Milestone__c milestoneRec = new Milestone__c(
            Name = 'Milestone',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today()
        );
        insert milestoneRec;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Milestone__c = milestoneRec.Id,
            Payment_Extension_Category__c = 'Upto 30 days',
            Original_Milestone_Date__c = Date.today(),
            Payment_Extension_Date__c = Date.today().addDays(20)
        );
        insert bp;

        List<Business_Process_Step__c> steps =
            new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Approval from CM Director',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 1,
            Business_Process_Steps_Name_Custom__c = 'CM',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Approval from CCO',
            Status__c = 'Accepted',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 2,
            Assigned_to__c=UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'CCO',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Approval from CEO',
            Status__c = 'Accepted',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 3,
             Assigned_to__c=UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'CEO',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Finance Verification',
            Status__c = 'Accepted',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 4,
             Assigned_to__c=UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Finance',
            Section_Number__c = 1,
            section_Name__c = 'Sec'
        ));

        insert steps;
    }

    @isTest
    static void testUpto30Days() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Required_Info_Step__c,
                   Business_Process__c,
                   Business_Process__r.Payment_Extension_Category__c,
                   Business_Process__r.Payment_Extension_No_Of_Days__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c previousStep = steps[0];

        Test.startTest();

        new PaymentMilestoneExtentionActivator().activateNextSteps(
            previousStep.Id,
            steps,
            previousStep,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testUpto60Days() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.Payment_Extension_Category__c = 'Upto 60 days';
        bp.Payment_Extension_Date__c = Date.today().addDays(45);
        update bp;

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Required_Info_Step__c,
                   Business_Process__c,
                   Business_Process__r.Payment_Extension_Category__c,
                   Business_Process__r.Payment_Extension_No_Of_Days__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c previousStep = steps[0];

        Test.startTest();

        new PaymentMilestoneExtentionActivator().activateNextSteps(
            previousStep.Id,
            steps,
            previousStep,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testMoreThan60Days() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.Payment_Extension_Category__c = 'More than 60 days';
        bp.Payment_Extension_Date__c = Date.today().addDays(75);
        update bp;

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Required_Info_Step__c,
                   Business_Process__c,
                   Business_Process__r.Payment_Extension_Category__c,
                   Business_Process__r.Payment_Extension_No_Of_Days__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c previousStep = steps[0];

        Test.startTest();

        new PaymentMilestoneExtentionActivator().activateNextSteps(
            previousStep.Id,
            steps,
            previousStep,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testFromCCO() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.Payment_Extension_Category__c = 'Upto 60 days';
        bp.Payment_Extension_Date__c = Date.today().addDays(45);
        update bp;

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Required_Info_Step__c,
                   Business_Process__c,
                   Business_Process__r.Payment_Extension_Category__c,
                   Business_Process__r.Payment_Extension_No_Of_Days__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c previousStep = steps[1];
        previousStep.Status__c = 'Completed';

        Test.startTest();

        new PaymentMilestoneExtentionActivator().activateNextSteps(
            previousStep.Id,
            steps,
            previousStep,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testRequiredInfo() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Required_Info_Step__c,
                   Business_Process__c,
                   Process_Flow_Step__c,
                   Business_Process__r.Payment_Extension_Category__c,
                   Business_Process__r.Payment_Extension_No_Of_Days__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c reqStep =
            new Business_Process_Step__c(
                Name = 'Required Info',
                Status__c = 'Required Info',
                Business_Process__c = steps[0].Business_Process__c,
                Sequence__c = 10,
                Business_Process_Steps_Name_Custom__c = 'Req',
                Section_Number__c = 1,
                Process_Flow_Step__c=steps[0].Process_Flow_Step__c,
                section_Name__c = 'Sec'
            );

        insert reqStep;

        Business_Process_Step__c previousStep = steps[0];
        previousStep.Required_Info_Step__c = reqStep.Id;

        Test.startTest();

        new PaymentMilestoneExtentionActivator().activateNextSteps(
            previousStep.Id,
            steps,
            previousStep,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testAssignedToBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Required_Info_Step__c,
                   Business_Process__c,
                   Business_Process__r.Payment_Extension_Category__c,
                   Business_Process__r.Payment_Extension_No_Of_Days__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c = UserInfo.getUserId();

        Business_Process_Step__c previousStep = steps[0];

        Test.startTest();

        new PaymentMilestoneExtentionActivator().activateNextSteps(
            previousStep.Id,
            steps,
            previousStep,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testReopenBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Required_Info_Step__c,
                   Business_Process__c,
                   Business_Process__r.Payment_Extension_Category__c,
                   Business_Process__r.Payment_Extension_No_Of_Days__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Re_Open_Count__c = 1;

        Business_Process_Step__c previousStep = steps[0];

        Test.startTest();

        new PaymentMilestoneExtentionActivator().activateNextSteps(
            previousStep.Id,
            steps,
            previousStep,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testRequiredInfoStatusBranch() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Sequence__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Required_Info_Step__c,
                   Business_Process__c,
                   Business_Process__r.Payment_Extension_Category__c,
                   Business_Process__r.Payment_Extension_No_Of_Days__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Status__c = 'Required Info';

        Business_Process_Step__c previousStep = steps[0];

        Test.startTest();

        new PaymentMilestoneExtentionActivator().activateNextSteps(
            previousStep.Id,
            steps,
            previousStep,
            null
        );

        Test.stopTest();
    }
}