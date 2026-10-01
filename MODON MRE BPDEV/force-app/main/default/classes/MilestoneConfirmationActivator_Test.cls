@isTest
public class MilestoneConfirmationActivator_Test {

    @testSetup
    static void setupData() {

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Milestone Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Milestone_Confirm_Test',
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
            Section_Number__c = 1,
            section_Name__c = 'S1',
            Business_Process_Steps_Name_Custom__c = 'S1',
            Process_Flow_Step__c = pfs.Id
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 2',
            Status__c = 'Required Info',
            Business_Process__c = bp.Id,
            Sequence__c = 2,
            Section_Number__c = 1,
            section_Name__c = 'S2',
            Business_Process_Steps_Name_Custom__c = 'S2',
            Process_Flow_Step__c = pfs.Id
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
            Process_Flow_Step__c = pfs.Id
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 4',
            Status__c = 'Open',
            Business_Process__c = bp.Id,
            Sequence__c = 4,
            Section_Number__c = 1,
            section_Name__c = 'S4',
            Business_Process_Steps_Name_Custom__c = 'S4',
            Process_Flow_Step__c = pfs.Id
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
                   Business_Process__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        Business_Process_Step__c prev = steps[0];
        prev.Required_Info_Step__c = steps[1].Id;

        Test.startTest();

        new MilestoneConfirmationActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testSequenceFlow_RequiredInfo() {

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

        Test.startTest();

        new MilestoneConfirmationActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    @isTest
    static void testReOpenBranch() {

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

        steps[1].Re_Open_Count__c = 1;

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new MilestoneConfirmationActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
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
                   Required_Info_Step__c,
                   Assigned_To__c,
                   Re_Open_Count__c,
                   Business_Process__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c = UserInfo.getUserId();

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new MilestoneConfirmationActivator().activateNextSteps(
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
                   Business_Process__c
            FROM Business_Process_Step__c
            ORDER BY Sequence__c
        ];

        steps[1].Assigned_To__c = null;
        steps[1].Re_Open_Count__c = 0;
        steps[1].Status__c = 'New';

        Business_Process_Step__c prev = steps[0];

        Test.startTest();

        new MilestoneConfirmationActivator().activateNextSteps(
            prev.Id,
            steps,
            prev,
            null
        );

        Test.stopTest();
    }

    // Builds a Business Process with a completed "CM Execute Milestone Update" step and a
    // not-yet-started "Finance Payment Verification" step.
    private static List<Business_Process_Step__c> createMilestoneUpdateSteps(Date extensionDate) {

        Process_Flow_Step__c pfs = [SELECT Id, Process_Flow__c FROM Process_Flow_Step__c LIMIT 1];
        Milestone__c ms = [SELECT Id FROM Milestone__c LIMIT 1];

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pfs.Process_Flow__c,
            Milestone__c = ms.Id,
            MileStone_Extension_Date__c = extensionDate
        );
        insert bp;

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>{
            new Business_Process_Step__c(
                Name = 'CM Execute Milestone Update',
                Status__c = 'Completed',
                Business_Process__c = bp.Id,
                Sequence__c = 1,
                Section_Number__c = 1,
                section_Name__c = 'S1',
                Business_Process_Steps_Name_Custom__c = 'CM Execute Milestone Update',
                Process_Flow_Step__c = pfs.Id
            ),
            new Business_Process_Step__c(
                Name = 'Finance Payment Verification',
                Status__c = 'Not Actioned',
                Business_Process__c = bp.Id,
                Sequence__c = 2,
                Section_Number__c = 1,
                section_Name__c = 'S2',
                Business_Process_Steps_Name_Custom__c = 'Finance Payment Verification',
                Process_Flow_Step__c = pfs.Id
            )
        };
        insert steps;

        return [
            SELECT Id, Name, Status__c, Sequence__c, Required_Info_Step__c, Assigned_To__c,
                   Re_Open_Count__c, Is_Process_End__c, Business_Process__c
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :bp.Id
            ORDER BY Sequence__c
        ];
    }

    @isTest
    static void testMilestoneExtensionCompletesProcess() {

        List<Business_Process_Step__c> steps = createMilestoneUpdateSteps(Date.today().addDays(30));
        Business_Process_Step__c prev = steps[0];

        // As in approveStep: the step was already saved as Completed in this transaction,
        // so the step trigger skips any further save of it.
        TriggerHandler.processedIds.add(prev.Id);

        Test.startTest();
        List<Business_Process_Step__c> opened = new MilestoneConfirmationActivator().activateNextSteps(
            prev.Id, steps, prev, null
        );
        Test.stopTest();

        System.assertEquals(0, opened.size(), 'No next step should be opened');

        Business_Process__c bp = [SELECT Status__c, End_Date__c FROM Business_Process__c WHERE Id = :prev.Business_Process__c];
        System.assertEquals('Completed', bp.Status__c, 'Business Process should be completed');
        System.assertNotEquals(null, bp.End_Date__c);

        System.assertEquals(true,
            [SELECT Is_Process_End__c FROM Business_Process_Step__c WHERE Id = :prev.Id].Is_Process_End__c,
            'Milestone update step should be flagged as process end');
        System.assertEquals('Not Actioned',
            [SELECT Status__c FROM Business_Process_Step__c WHERE Id = :steps[1].Id].Status__c,
            'Finance Payment Verification must stay closed');
    }

    @isTest
    static void testNoMilestoneExtensionOpensNextStep() {

        List<Business_Process_Step__c> steps = createMilestoneUpdateSteps(null);
        Business_Process_Step__c prev = steps[0];

        Test.startTest();
        List<Business_Process_Step__c> opened = new MilestoneConfirmationActivator().activateNextSteps(
            prev.Id, steps, prev, null
        );
        Test.stopTest();

        System.assertEquals(1, opened.size(), 'Next step should be opened');
        System.assertEquals('Open',
            [SELECT Status__c FROM Business_Process_Step__c WHERE Id = :steps[1].Id].Status__c);
        System.assertNotEquals('Completed',
            [SELECT Status__c FROM Business_Process__c WHERE Id = :prev.Business_Process__c].Status__c);
    }
}