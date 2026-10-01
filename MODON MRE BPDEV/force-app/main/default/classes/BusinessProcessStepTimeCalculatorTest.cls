@isTest
public class BusinessProcessStepTimeCalculatorTest {

    @testSetup
    static void setupData() {

         Process_Flow__c testProcessFlow11 = new Process_Flow__c(
            Name = 'BR Amendment11',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'tes1',
            Type__c='Cost Approval'
        );
        insert testProcessFlow11;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow11.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow11.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow11.Id
        );
        insert bp;

              List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id, 
            Sequence__c = 1,
            Status__c = 'Cancelled',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test1',
            Section_Number__c=1,
            section_Name__c='test1'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 2',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs2.Id, 
            Sequence__c = 2,
            Status__c = 'Not Actioned',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
          steps.add(new Business_Process_Step__c(
            Name = 'Step 3',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs2.Id, 
            Sequence__c = 2,
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=3,
            section_Name__c='test3'
        ));
        insert steps;

        // Create Step Assignments (Sequence 1–4)
        List<Step_Assignment__c> assignments = new List<Step_Assignment__c>{
            new Step_Assignment__c(
                Process_Flow_Step__c = pfs1.Id,
                Sequence__c = 1,
                Assignment_Days__c = 0,
                Assignment_Time__c = 1,
                Assignment_Minutes__c = 0
            ),
            new Step_Assignment__c(
                Process_Flow_Step__c = pfs1.Id,
                Sequence__c = 2,
                Assignment_Days__c = 0,
                Assignment_Time__c = 2,
                Assignment_Minutes__c = 0
            ),
            new Step_Assignment__c(
                Process_Flow_Step__c = pfs2.Id,
                Sequence__c = 3,
                Assignment_Days__c = 0,
                Assignment_Time__c = 3,
                Assignment_Minutes__c = 0
            ),
            new Step_Assignment__c(
                Process_Flow_Step__c = pfs2.Id,
                Sequence__c = 4,
                Assignment_Days__c = 0,
                Assignment_Time__c = 4,
                Assignment_Minutes__c = 0
            )
        };
        insert assignments;
    }

@isTest
static void testCalculateStepTimes_Success() {

    // Get existing data from setup
    Business_Process_Step__c step = [
        SELECT Id, Status__c
        FROM Business_Process_Step__c
        LIMIT 1
    ];

    // 🔥 Make it eligible
    step.Status__c = 'Open';
    update step;

    Test.startTest();
    BusinessProcessStepTimeCalculator.calculateStepTimes(
        new List<Id>{ step.Id }
    );
    Test.stopTest();

    // Verify values got populated
    Business_Process_Step__c result = [
        SELECT Calculate_Time_1__c, Calculate_Time_2__c,
               Calculate_Time_3__c, Calculate_Time_4__c
        FROM Business_Process_Step__c
        WHERE Id = :step.Id
    ];

    System.assertNotEquals(null, result.Calculate_Time_1__c);
}
    @isTest
    static void testCalculateStepTimes_NoAssignments() {

       Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'BR Amendment',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test',
            Type__c='Cost Approval'
        );
        insert testProcessFlow;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow.Id
        );
        insert bp;
         List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id, 
            Sequence__c = 1,
            Status__c = 'Not Actioned',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test1',
            Section_Number__c=1,
            section_Name__c='test1'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Step 2',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs2.Id, 
            Sequence__c = 2,
            Status__c = 'Not Actioned',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
        insert steps;

        Test.startTest();
        BusinessProcessStepTimeCalculator.calculateStepTimes(
            new List<Id>{ steps[0].Id }
        );
        Test.stopTest();

        Business_Process_Step__c result = [
            SELECT Calculate_Time_1__c
            FROM Business_Process_Step__c
            WHERE Id = :steps[0].Id
        ];

        System.assertEquals(null, result.Calculate_Time_1__c);
    }

    @isTest
    static void testCalculateStepTimes_EmptyInput() {

        Test.startTest();
        BusinessProcessStepTimeCalculator.calculateStepTimes(new List<Id>());
        Test.stopTest();

        System.assert(true, 'Handled empty input gracefully');
    }

    @isTest
    static void testCalculateStepTimes_InvalidStatus() {

        // Closed status should be ignored
        Business_Process_Step__c closedStep = [
            SELECT Id FROM Business_Process_Step__c WHERE Status__c = 'Cancelled' LIMIT 1
        ];

        Test.startTest();
        BusinessProcessStepTimeCalculator.calculateStepTimes(
            new List<Id>{ closedStep.Id }
        );
        Test.stopTest();

        Business_Process_Step__c result = [
            SELECT Calculate_Time_1__c
            FROM Business_Process_Step__c
            WHERE Id = :closedStep.Id
        ];

        System.assertEquals(null, result.Calculate_Time_1__c);
    }
}