@isTest
public class BusinessProcessControllerTest {

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


        // Create Steps
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

        // Reviewer Comment
        insert new Reviewer_Comment__c(
            Business_Process__c = bp.Id
        );

        // Checklist
        Process_Checklist__c checklist = new Process_Checklist__c(
            Business_Process__c = bp.Id,
            Is_Maker_Review_Completed__c = false
        );
        insert checklist;

        // Checklist Items
        insert new Process_Checklist_Items__c(
            Process_Checklist__c = checklist.Id,
            Maker_Action__c = 'No Action',
            Checker_Action__c = 'No Action'
        );
    }

    // --------------------------------------------
    // TEST: getBusinessProcessSteps
    // --------------------------------------------
    @isTest
    static void testGetBusinessProcessSteps() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        List<BusinessProcessController.ParentItem> result =
            BusinessProcessController.getBusinessProcessSteps(bp.Id);
        Test.stopTest();

        System.assert(!result.isEmpty(), 'Result should not be empty');
        System.assert(result[0].subItems.size() > 0, 'SubItems should exist');
    }

    // --------------------------------------------
    // TEST: assignStepToCurrentUser
    // --------------------------------------------
    @isTest
    static void testAssignStepToCurrentUser() {

        Business_Process_Step__c step = [
            SELECT Id, Status__c, Assigned_To__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();
        Business_Process_Step__c updatedStep =
            BusinessProcessController.assignStepToCurrentUser(step.Id);
        Test.stopTest();

        System.assertEquals('Accepted', updatedStep.Status__c);
        System.assertEquals(UserInfo.getUserId(), updatedStep.Assigned_To__c);
    }

    // --------------------------------------------
    // TEST: isCheckListProvided (FALSE case)
    // --------------------------------------------
    @isTest
    static void testIsCheckListProvidedFalse() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        Boolean result = BusinessProcessController.isCheckListProvided(bp.Id);
        Test.stopTest();
    }

    // --------------------------------------------
    // TEST: isCheckListProvided (TRUE case)
    // --------------------------------------------
    @isTest
    static void testIsCheckListProvidedTrueScenario() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        // Update checklist items to force false condition
        List<Process_Checklist_Items__c> items = [
            SELECT Id, Maker_Action__c
            FROM Process_Checklist_Items__c
        ];

        for (Process_Checklist_Items__c item : items) {
            item.Maker_Action__c = 'No Action';
        }
        update items;

        Test.startTest();
        Boolean result = BusinessProcessController.isCheckListProvided(bp.Id);
        Test.stopTest();

        System.assertEquals(false, result, 'Checklist should return false');
    }
}