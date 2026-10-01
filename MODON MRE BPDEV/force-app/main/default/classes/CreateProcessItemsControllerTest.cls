@isTest
public class CreateProcessItemsControllerTest {

    @testSetup
    static void setupData() {

          Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'Clash Approval',
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

        // Checklist Metadata
        Checklist_Metadata__c checklist = new Checklist_Metadata__c(
            Check_List_Process_Name__c = 'SPA',
            Checklist_Name_in_short__c = 'CHK1'
        );
        insert checklist;

        // Checklist Item Metadata
        Checklist_Item_Metadata__c item1 = new Checklist_Item_Metadata__c(
            Checklist_Item_Metadata_Name__c = 'Item One',
            Sequence__c = 1,
            Checklist_Metadata__c = checklist.Id
        );

        Checklist_Item_Metadata__c item2 = new Checklist_Item_Metadata__c(
            Checklist_Item_Metadata_Name__c = 'Item Two',
            Sequence__c = 2,
            Checklist_Metadata__c = checklist.Id
        );

        insert new List<Checklist_Item_Metadata__c>{ item1, item2 };

        // Process Flow Document
        Process_Flow_Document__c doc1 = new Process_Flow_Document__c(
            Name = 'Doc 1',
            Process_Flow__c=testProcessFlow.Id,
            Checklist_Item_Metadata__c = item1.Id
        );

        Process_Flow_Document__c doc2 = new Process_Flow_Document__c(
            Name = 'Doc 2',
            Process_Flow__c=testProcessFlow.Id,
            Checklist_Item_Metadata__c = item2.Id
        );

        insert new List<Process_Flow_Document__c>{ doc1, doc2 };
    }

    @isTest
    static void testGetChecklistProcessNames() {

        Test.startTest();
        List<String> result = CreateProcessItemsController.getChecklistProcessNames();
        Test.stopTest(); 
    }

    @isTest
    static void testGetChecklistNamesByProcess() {

        Test.startTest();
        List<String> result =
            CreateProcessItemsController.getChecklistNamesByProcess('Process A');
        Test.stopTest();
    }

    @isTest
    static void testCreateProcessChecklist() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        CreateProcessItemsController.createProcessChecklist('CHK1', bp.Id);
        Test.stopTest();

        // Verify Process Checklist created
        List<Process_Checklist__c> pcl = [
            SELECT Id, Business_Process__c
            FROM Process_Checklist__c
            WHERE Business_Process__c = :bp.Id
        ];

        System.assertEquals(1, pcl.size());

        // Verify Process Items created
        List<Process_Checklist_Items__c> items = [
            SELECT Id
            FROM Process_Checklist_Items__c
            WHERE Process_CheckList__c = :pcl[0].Id
        ];

        System.assert(items.size() > 0);

        // Verify Business Process updated
        Business_Process__c updatedBP = [
            SELECT Latest_Process_Checklist__c
            FROM Business_Process__c
            WHERE Id = :bp.Id
        ];

        System.assertEquals(pcl[0].Id, updatedBP.Latest_Process_Checklist__c);
    }

    @isTest
    static void testCreateProcessChecklist_blankName() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        try {
            CreateProcessItemsController.createProcessChecklist('', bp.Id);
            System.assert(false, 'Expected exception not thrown');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Checklist name cannot be blank'));
        }
        Test.stopTest();
    }
}