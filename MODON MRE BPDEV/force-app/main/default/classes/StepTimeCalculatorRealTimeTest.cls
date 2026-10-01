@isTest
public class StepTimeCalculatorRealTimeTest {

    @testSetup
    static void setupData() {
        
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

        // Create Time Logs
        List<Business_Process_Step_Time_Log__c> logs = new List<Business_Process_Step_Time_Log__c>();

        Datetime startTime = System.now().addHours(-3);

        logs.add(new Business_Process_Step_Time_Log__c(
            Business_Process_Step__c = steps[0].Id,
            Start_time__c = startTime,
            End_Time__c = startTime.addHours(1),
            New_Status__c = 'Open'
        ));

        logs.add(new Business_Process_Step_Time_Log__c(
            Business_Process_Step__c = steps[0].Id,
            Start_time__c = startTime.addHours(1),
            End_Time__c = startTime.addHours(2),
            New_Status__c = 'Accepted'
        ));

        logs.add(new Business_Process_Step_Time_Log__c(
            Business_Process_Step__c = steps[1].Id,
            Start_time__c = startTime.addHours(2),
            End_Time__c = null, // still running
            New_Status__c = 'Re Open'
        ));

        insert logs;
    }

    @isTest
    static void testGetTimelineMetadata() {
        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        Test.startTest();
        StepTimeCalculatorRealTime.StepTimeCalculationOutput output =
            StepTimeCalculatorRealTime.getTimelineMetadata(step.Id);
        Test.stopTest();
    }

    @isTest
    static void testCalculateTimelineDirect() {
        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        List<Business_Process_Step_Time_Log__c> logs = [
            SELECT Start_time__c, End_Time__c, New_Status__c
            FROM Business_Process_Step_Time_Log__c
            WHERE Business_Process_Step__c = :step.Id
        ];

        StepTimeCalculatorRealTime.StepTimeCalculationInput input =
            new StepTimeCalculatorRealTime.StepTimeCalculationInput();

        input.timeLogs = logs;
        input.milestoneHours = 2;
        input.reopenCount = 1;

        // Fetch default business hours
        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        input.businessHoursId = bh.Id;

        Test.startTest();
        StepTimeCalculatorRealTime.StepTimeCalculationOutput output =
            StepTimeCalculatorRealTime.calculateTimeline(input);
        Test.stopTest();
    }

    @isTest
    static void testNoLogsScenario() {
        StepTimeCalculatorRealTime.StepTimeCalculationInput input =
            new StepTimeCalculatorRealTime.StepTimeCalculationInput();

        input.timeLogs = new List<Business_Process_Step_Time_Log__c>();
        input.milestoneHours = 1;
        input.reopenCount = 0;

        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        input.businessHoursId = bh.Id;
    }
}