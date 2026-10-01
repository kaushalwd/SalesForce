@isTest
public class SPAExecutionChecklistToPDFTest {

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

        // Create Business Process Document
        Business_Process_Documents__c bpDoc = new Business_Process_Documents__c(
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

        // Create Business Process Steps (Maker & Checker)
        User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

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

    @isTest
    static void testGenerateAndAttach_Success() {
        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        SPAExecutionChecklistToPDF.InputWrapper input = new SPAExecutionChecklistToPDF.InputWrapper();
        input.businessProcessId = bp.Id;

        Test.startTest();
        List<SPAExecutionChecklistToPDF.OutputWrapper> result =
            SPAExecutionChecklistToPDF.generateAndAttach(new List<SPAExecutionChecklistToPDF.InputWrapper>{ input });
        Test.stopTest();
  
    }

    @isTest
    static void testGenerateAndAttach_NoInput() {
        Test.startTest();
        List<SPAExecutionChecklistToPDF.OutputWrapper> result =
            SPAExecutionChecklistToPDF.generateAndAttach(new List<SPAExecutionChecklistToPDF.InputWrapper>());
        Test.stopTest();

        System.assertEquals('Error', result[0].status);
        System.assert(result[0].message.contains('No input'));
    }

    @isTest
    static void testGenerateAndAttach_NullBPId() {
        SPAExecutionChecklistToPDF.InputWrapper input = new SPAExecutionChecklistToPDF.InputWrapper();
        input.businessProcessId = null;

        Test.startTest();
        List<SPAExecutionChecklistToPDF.OutputWrapper> result =
            SPAExecutionChecklistToPDF.generateAndAttach(new List<SPAExecutionChecklistToPDF.InputWrapper>{ input });
        Test.stopTest();

        System.assertEquals('Error', result[0].status);
        System.assert(result[0].message.contains('Business Process ID is required'));
    }

    @isTest
    static void testVisualforceConstructor() {
        Business_Process__c bp = [SELECT Id,Name FROM Business_Process__c LIMIT 1];

        Test.startTest();
        PageReference pageRef = Page.SPAExecutionChecklistPDF;
        pageRef.getParameters().put('id', bp.Id);
        Test.setCurrentPage(pageRef);

        SPAExecutionChecklistToPDF controller = new SPAExecutionChecklistToPDF();
        Test.stopTest();

        System.assertNotEquals(null, controller);
        System.assertEquals(bp.Name, controller.bpNumber);
    }
}