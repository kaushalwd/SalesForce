@isTest
public class StepOwnershipSummaryTest {

    @testSetup
    static void setupData() {

        // Create Business Hours (Required for BusinessHours.diff)
        BusinessHours bh = [SELECT Id FROM BusinessHours LIMIT 1];
    
 Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'Clash Approval',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test',
            Type__c='Cost Approval',
            Business_Hours_ID__c = bh.Id
        );
        insert testProcessFlow;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Step_Name__c = 'Customer Payment Completion',
            Section_Number__c = 1,
            section_Name__c = 'TES1',
            Process_Flow__c = testProcessFlow.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Step_Name__c = 'Step 2',
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
            Name = 'Customer Payment Completion',
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
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
        insert steps;

        // Create Test User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            Alias = 'testu',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;

        // Create Time Logs
        List<Business_Process_Step_Time_Log__c> logs = new List<Business_Process_Step_Time_Log__c>();

        logs.add(new Business_Process_Step_Time_Log__c(
            Business_Process_Step__c = steps[0].Id,
            Step_Assigned_User__c = u.Id,
            Start_time__c = System.now().addHours(-2),
            End_Time__c = System.now().addHours(-1)
        ));

        logs.add(new Business_Process_Step_Time_Log__c(
            Business_Process_Step__c = steps[0].Id,
            Step_Assigned_User__c = u.Id,
            Start_time__c = System.now().addHours(-1),
            End_Time__c = System.now()
        ));

        insert logs;
    }

    @isTest
    static void testUpdateOwnershipSummary() {

        // Fetch step
        Business_Process_Step__c step = [
            SELECT Id, Process_Flow_Step__c,
                   Process_Flow_Step__r.Process_Flow__r.Business_Hours_ID__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        // Prepare inputs
        Set<Id> stepIds = new Set<Id>{ step.Id };

        Map<Id, Business_Process_Step__c> processFlowMap = new Map<Id, Business_Process_Step__c>{
            step.Id => step
        };

        Test.startTest();
        StepOwnershipSummary.updateOwnershipSummary(stepIds, processFlowMap);
        Test.stopTest();

        // Verify result
        Business_Process_Step__c updatedStep = [
            SELECT Step_Ownership_Summary__c
            FROM Business_Process_Step__c
            WHERE Id = :step.Id
        ];

        System.assertNotEquals(null, updatedStep.Step_Ownership_Summary__c, 'Summary should not be null');
        System.assert(
            updatedStep.Step_Ownership_Summary__c.contains('mins'),
            'Summary should contain minutes'
        );
    }
}