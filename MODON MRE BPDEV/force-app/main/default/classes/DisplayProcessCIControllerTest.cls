@isTest
public class DisplayProcessCIControllerTest {

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

        // Create Process Checklist
        Process_Checklist__c pc = new Process_Checklist__c(
            Name__c = 'Test Checklist',
            Business_Process__c = bp.Id
        );
        insert pc;

        // Create Checklist Item
        Process_Checklist_Items__c item = new Process_Checklist_Items__c(
            Process_Checklist__c = pc.Id,
            Checklist_Name__c = 'Test Item',
            Maker_Comments__c = 'Test Comment',
            Sequence__c = 1
        );
        insert item;
    }

    @isTest
    static void testGetSimpleChecklistItems() {
        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = DisplayProcessChecklistItemController.getSimpleChecklistItems(bp.Id);
        Test.stopTest();

        System.assert(result != null);
        System.assert(result.containsKey('checklistItems'));
        System.assert(result.containsKey('checkListName'));
        System.assert(result.containsKey('processChecklistId'));
    }

    @isTest
    static void testCreateSimpleChecklistItem() {
        Process_Checklist__c pc = [SELECT Id FROM Process_Checklist__c LIMIT 1];

        Test.startTest();
        Process_Checklist_Items__c newItem =
            DisplayProcessChecklistItemController.createSimpleChecklistItem(
                pc.Id,
                'New Item',
                'New Comment'
            );
        Test.stopTest();

        System.assertNotEquals(null, newItem.Id);
        System.assertEquals('New Item', newItem.Checklist_Name__c);
    }

    @isTest
    static void testUpdateSimpleChecklistItem() {
        Process_Checklist_Items__c item =
            [SELECT Id FROM Process_Checklist_Items__c LIMIT 1];

        Test.startTest();
        DisplayProcessChecklistItemController.updateSimpleChecklistItem(
            item.Id,
            'Updated Name',
            'Updated Comment'
        );
        Test.stopTest();

        Process_Checklist_Items__c updated =
            [SELECT Checklist_Name__c, Maker_Comments__c FROM Process_Checklist_Items__c WHERE Id = :item.Id];

        System.assertEquals('Updated Name', updated.Checklist_Name__c);
        System.assertEquals('Updated Comment', updated.Maker_Comments__c);
    }

    @isTest
    static void testDeleteSimpleChecklistItem() {
        Process_Checklist_Items__c item =
            [SELECT Id FROM Process_Checklist_Items__c LIMIT 1];

        Test.startTest();
        DisplayProcessChecklistItemController.deleteSimpleChecklistItem(item.Id);
        Test.stopTest();

        List<Process_Checklist_Items__c> items =
            [SELECT Id FROM Process_Checklist_Items__c WHERE Id = :item.Id];

        System.assertEquals(0, items.size());
    }

    @isTest
    static void testCreateProcessChecklist() {
   
 Process_Flow__c testProcessFlow1 = new Process_Flow__c(
            Name = 'BR Amendment',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test1',
            Type__c='Cost Approval'
        );
        insert testProcessFlow1;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Section_Number__c=1,
            section_Name__c='TES1',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs1;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = testProcessFlow1.Id
        );
        insert pfs2;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c =testProcessFlow1.Id
        );
        insert bp;

        Test.startTest();
        DisplayProcessChecklistItemController.createProcessChecklist(
            'New Checklist',
            bp.Id
        );
        Test.stopTest();

        Process_Checklist__c pc =
            [SELECT Id FROM Process_Checklist__c WHERE Business_Process__c = :bp.Id LIMIT 1];

        System.assertNotEquals(null, pc);

        List<Process_Checklist_Items__c> items =
            [SELECT Id FROM Process_Checklist_Items__c WHERE Process_Checklist__c = :pc.Id];

        System.assert(items.size() > 0);
    }

    @isTest
    static void testCreateProcessChecklist_Exceptions() {
        Test.startTest();

        try {
            DisplayProcessChecklistItemController.createProcessChecklist('', null);
            System.assert(false);
        } catch (Exception e) {
            System.assert(true);
        }

        Test.stopTest();
    }
}