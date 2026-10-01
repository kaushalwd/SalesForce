@isTest
private class MakerCheckerChecklistToPdfControllerTest {
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

        // Business Process Document
        Business_Process_Documents__c bpDoc = new Business_Process_Documents__c(
            Name = 'BP Doc Test',
            Business_Process__c = bp.Id
        );
        insert bpDoc;

        // Process Checklist
        Process_Checklist__c pc = new Process_Checklist__c(
            Business_Process__c = bp.Id
        );
        insert pc;

        // Checklist Items
        List<Process_Checklist_Items__c> items = new List<Process_Checklist_Items__c>();

        for (Integer i = 1; i <= 3; i++) {
            items.add(new Process_Checklist_Items__c(
                Process_Checklist__c = pc.Id,
                Sequence__c = i,
                Maker_Action__c = 'No Action',
                Checker_Action__c = 'No Action'
            ));
        }
        insert items;

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
    }

    // ----------------------------
    // TEST: INVOCABLE METHOD
    // ----------------------------
    @isTest
    static void testGenerateAndAttach_Success() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        MakerCheckerChecklistToPdfController.InputWrapper req =
            new MakerCheckerChecklistToPdfController.InputWrapper();
        req.businessProcessId = bp.Id;

        List<MakerCheckerChecklistToPdfController.InputWrapper> requests =
            new List<MakerCheckerChecklistToPdfController.InputWrapper>{ req };

        Test.startTest();
        List<MakerCheckerChecklistToPdfController.OutputWrapper> result =
            MakerCheckerChecklistToPdfController.generateAndAttach(requests);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('Success', result[0].status);
        System.assertEquals(true, result[0].message.contains('successfully'));
    }

    // ----------------------------
    // TEST: NULL INPUT
    // ----------------------------
    @isTest
    static void testGenerateAndAttach_NullInput() {

        Test.startTest();
        List<MakerCheckerChecklistToPdfController.OutputWrapper> result =
            MakerCheckerChecklistToPdfController.generateAndAttach(null);
        Test.stopTest();

        System.assertEquals('Error', result[0].status);
        System.assertEquals('No input received.', result[0].message);
    }

    // ----------------------------
    // TEST: NULL BP ID
    // ----------------------------
    @isTest
    static void testGenerateAndAttach_NullBpId() {

        MakerCheckerChecklistToPdfController.InputWrapper req =
            new MakerCheckerChecklistToPdfController.InputWrapper();

        List<MakerCheckerChecklistToPdfController.InputWrapper> requests =
            new List<MakerCheckerChecklistToPdfController.InputWrapper>{ req };

        Test.startTest();
        List<MakerCheckerChecklistToPdfController.OutputWrapper> result =
            MakerCheckerChecklistToPdfController.generateAndAttach(requests);
        Test.stopTest();

        System.assertEquals('Error', result[0].status);
        System.assertEquals('Business Process ID is required.', result[0].message);
    }

    // ----------------------------
    // TEST: VISUALFORCE CONTROLLER
    // ----------------------------
    @isTest
    static void testConstructor() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        PageReference pageRef = Page.MakerCheckerChecklistPdf;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', bp.Id);

        Test.startTest();
        MakerCheckerChecklistToPdfController controller =
            new MakerCheckerChecklistToPdfController();
        Test.stopTest();

        System.assertNotEquals(null, controller.bpNumber);
    }

    @isTest
    static void testConstructor_NoChecklist() {
 Process_Flow__c testProcessFlow11 = new Process_Flow__c(
            Name = 'BR Amendment11',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test11',
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

        // Remove checklist dependency scenario (edge case)
        delete [SELECT Id FROM Process_Checklist_Items__c];

        PageReference pageRef = Page.MakerCheckerChecklistPdf;
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('id', bp.Id);

        Test.startTest();
        MakerCheckerChecklistToPdfController controller =
            new MakerCheckerChecklistToPdfController();
        Test.stopTest();

    }
}