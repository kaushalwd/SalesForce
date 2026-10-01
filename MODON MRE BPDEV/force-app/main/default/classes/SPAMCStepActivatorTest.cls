@isTest
public class SPAMCStepActivatorTest {

    @isTest
    static void testActivateNextSteps_basicFlow() {
        
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

        // Create previous step
        Business_Process_Step__c previousStep = new Business_Process_Step__c(
            Name = 'SPA Maker Verification',
            Status__c = 'Completed'
        );
        
        

        // Create next step (target)
        Business_Process_Step__c nextStep = new Business_Process_Step__c(
            Id = steps[0].Id,
            Name = 'SPA Checklist Checker Verification',
            Status__c = 'Open'
        );

        List<Business_Process_Step__c> stepList = new List<Business_Process_Step__c>{ nextStep };

        // Instantiate class
        SPAMCStepActivator activator = new SPAMCStepActivator();

        Test.startTest();
        List<Business_Process_Step__c> result = activator.activateNextSteps(
            null,
            stepList,
            previousStep,
            null
        );
        Test.stopTest();

    }

    @isTest
    static void testActivateNextSteps_requiredInfoFlow() {
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

        Business_Process_Step__c previousStep = new Business_Process_Step__c(
            Name = 'SPA Maker Verification',
            Status__c = 'Completed'
        );

        Business_Process_Step__c nextStep = new Business_Process_Step__c(
            Id = steps[0].Id,
            Name = 'SPA Checklist Checker Verification',
            Status__c = 'Required Info'
        );

        List<Business_Process_Step__c> stepList = new List<Business_Process_Step__c>{ nextStep };

        SPAMCStepActivator activator = new SPAMCStepActivator();

        List<Business_Process_Step__c> result = activator.activateNextSteps(
            null,
            stepList,
            previousStep,
            null
        );

    }

    @isTest
    static void testActivateNextSteps_withAssignedUser() {

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
        Business_Process_Step__c previousStep = new Business_Process_Step__c(
            Name = 'SPA Maker Verification',
            Status__c = 'Completed'
        );

        Business_Process_Step__c nextStep = new Business_Process_Step__c(
            Id = steps[0].Id,
            Name = 'SPA Checklist Checker Verification',
            Assigned_To__c = UserInfo.getUserId()
        );

        List<Business_Process_Step__c> stepList = new List<Business_Process_Step__c>{ nextStep };

        SPAMCStepActivator activator = new SPAMCStepActivator();

        List<Business_Process_Step__c> result = activator.activateNextSteps(
            null,
            stepList,
            previousStep,
            null
        );

    }

    @isTest
    static void testActivateNextSteps_withNextOwnerOverride() {
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
        Business_Process_Step__c previousStep = new Business_Process_Step__c(
            Name = 'SPA Maker Verification',
            Status__c = 'Completed'
        );

        Business_Process_Step__c nextStep = new Business_Process_Step__c(
            Id = steps[0].Id,
            Name = 'SPA Checklist Checker Verification',
            Status__c = 'Open'
        );

        List<Business_Process_Step__c> stepList = new List<Business_Process_Step__c>{ nextStep };

        SPAMCStepActivator activator = new SPAMCStepActivator();

        Id newOwnerId = UserInfo.getUserId();

        List<Business_Process_Step__c> result = activator.activateNextSteps(
            null,
            stepList,
            previousStep,
            newOwnerId
        );

    }

    @isTest
    static void testActivateNextSteps_noMatchCondition() {
        
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

        Business_Process_Step__c previousStep = new Business_Process_Step__c(
            Name = 'Other Step',
            Status__c = 'Completed'
        );

        Business_Process_Step__c nextStep = new Business_Process_Step__c(
            Id = steps[0].Id,
            Name = 'SPA Checklist Checker Verification'
        );

        List<Business_Process_Step__c> stepList = new List<Business_Process_Step__c>{ nextStep };

        SPAMCStepActivator activator = new SPAMCStepActivator();

        List<Business_Process_Step__c> result = activator.activateNextSteps(
            null,
            stepList,
            previousStep,
            null
        );

    }
}