@isTest
private class BusinessProcessStepTriggerHandlerTest {

    @testSetup
    static void setupData() {

        BusinessHours bh = [
            SELECT Id
            FROM BusinessHours
            WHERE IsDefault = true
            LIMIT 1
        ];

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
    }

    static Business_Process_Step__c createStep(String status) {
        Process_Flow_Step__c pfs = [SELECT Id FROM Process_Flow_Step__c LIMIT 1];
        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        return new Business_Process_Step__c(
            Name = 'Step Test',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Status__c = status
        );
    }

    @isTest
    static void testBeforeInsert_OPEN() {

  Process_Flow__c testProcessFlow4 = new Process_Flow__c(
            Name = 'BR Amendment',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test4',
            Type__c='Cost Approval'
        );
        insert testProcessFlow4;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow4.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow4.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow4.Id
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
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
        

      
        Test.startTest();
        insert steps;
        Test.stopTest();

       // steps[0] = [SELECT Step_Open_Time__c FROM Business_Process_Step__c WHERE Id = :steps[0].Id];
    }

    @isTest
    static void testBeforeUpdate_Assign() {

       
  Process_Flow__c testProcessFlow4 = new Process_Flow__c(
            Name = 'BR Amendment',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test4',
            Type__c='Cost Approval'
        );
        insert testProcessFlow4;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow4.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow4.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow4.Id
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
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
            insert steps;

        steps[0].Assigned_To__c = UserInfo.getUserId();

        Test.startTest();
        update steps[0];
        Test.stopTest();

        Business_Process_Step__c updated = [
            SELECT Status__c, Assigned_Time__c
            FROM Business_Process_Step__c
            WHERE Id = :steps[0].Id
        ];
    }

    @isTest
    static void testBeforeUpdate_Status_Completed() {  
  Process_Flow__c testProcessFlow5 = new Process_Flow__c(
            Name = 'BR Amendment',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test5',
            Type__c='Cost Approval'
        );
        insert testProcessFlow5;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow5.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow5.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow5.Id
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
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
            insert steps;

        steps[0].Status__c = 'Completed';

        Test.startTest();
        update steps[0];
        Test.stopTest();

        steps[0] = [
            SELECT Completed_Time__c
            FROM Business_Process_Step__c
            WHERE Id = :steps[0].Id
        ];
    }

    @isTest
    static void testAfterInsert_LogCreation() {

       Process_Flow__c testProcessFlow2 = new Process_Flow__c(
            Name = 'Clash Approval',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test2',
            Type__c='Cost Approval'
        );
        insert testProcessFlow2;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow2.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow2.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow2.Id
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
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
        

        Test.startTest();
      insert steps;
        Test.stopTest();

        List<Business_Process_Step_Time_Log__c> logs = [
            SELECT Id FROM Business_Process_Step_Time_Log__c
            WHERE Business_Process_Step__c = :steps[0].Id
        ];
    }

    @isTest
    static void testAfterUpdate_StatusChangeLogs() {

      Process_Flow__c testProcessFlow3 = new Process_Flow__c(
            Name = 'Clash Approval',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test3',
            Type__c='Cost Approval'
        );
        insert testProcessFlow3;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow3.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow3.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow3.Id
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
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
      insert steps;
       

        steps[0].Status__c = 'Provided Info';

        Test.startTest();
        update steps[0];
        Test.stopTest();

        List<Business_Process_Step_Time_Log__c> logs = [
            SELECT Id, New_Status__c
            FROM Business_Process_Step_Time_Log__c
            WHERE Business_Process_Step__c = :steps[0].Id
        ];
    }

    @isTest
    static void testHandleReassignFlow() {

        User u = [SELECT Id FROM User LIMIT 1];

         Process_Flow__c testProcessFlow5 = new Process_Flow__c(
            Name = 'BR Amendment',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test5',
            Type__c='Cost Approval'
        );
        insert testProcessFlow5;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow5.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow5.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow5.Id
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
            OwnerId =  UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
            insert steps;

        steps[0].Assigned_To__c = UserInfo.getUserId();

        Test.startTest();
        update steps[0];
        Test.stopTest();

        Business_Process_Step__c updated = [
            SELECT Status__c, Re_Assign_Time__c, Re_Assign_Count__c
            FROM Business_Process_Step__c
            WHERE Id = :steps[0].Id
        ];
    }

    @isTest
    static void testProcessEndCompleted() {
        BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1];
        Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'Process End Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'process_end_flow',
            Type__c = 'Cost Approval',
            Business_Hours_ID__c = bh.Id
        );
        insert testProcessFlow;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c = 1,
            section_Name__c = 'End Section 1',
            Process_Flow__c = testProcessFlow.Id,
            Duration_To_Complete_In_Hourss__c = '5'
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c = 2,
            section_Name__c = 'End Section 2',
            Process_Flow__c = testProcessFlow.Id,
            Duration_To_Complete_In_Hourss__c = '10'
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = testProcessFlow.Id
        );
        insert bp;

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();
        steps.add(new Business_Process_Step__c(
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id,
            Sequence__c = 1,
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'step1',
            Section_Number__c = 1,
            section_Name__c = 'step1',
            Is_Process_End__c = false
        ));
        steps.add(new Business_Process_Step__c(
            Name = 'Final Step',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs2.Id,
            Sequence__c = 2,
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'final_step',
            Section_Number__c = 2,
            section_Name__c = 'final',
            Is_Process_End__c = true
        ));
        insert steps;

        Test.startTest();
        TriggerHandler.processedIds.clear();
        steps[0].Status__c = 'Required Info';
        update steps[0];

        TriggerHandler.processedIds.clear();
        steps[0].Status__c = 'Provided Info';
        update steps[0];

        TriggerHandler.processedIds.clear();
        steps[1].Status__c = 'Completed';
        update steps[1];
        Test.stopTest();
    }

    @isTest
    static void testProcessCancelled() {
        Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'Cancel Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'cancel_flow',
            Type__c = 'Cost Approval'
        );
        insert testProcessFlow;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Section_Number__c = 1,
            section_Name__c = 'Cancel Section',
            Process_Flow__c = testProcessFlow.Id
        );
        insert pfs;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = testProcessFlow.Id
        );
        insert bp;

        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Cancel Step',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 1,
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'cancel_step',
            Section_Number__c = 1,
            section_Name__c = 'cancel'
        );
        insert step;

        Test.startTest();
        TriggerHandler.processedIds.clear();
        step.Status__c = 'Cancelled';
        update step;
        Test.stopTest();
    }
}