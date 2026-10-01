@isTest
private class SPAMCStepActivatoTest {
    
    @testSetup
    static void setupData() {
        Map<String,Id> recordIdMap = new Map<String,Id>();
        
        Business_Process__c bp = new Business_Process__c();
        insert bp;
        
        Process_Checklist__c checklist = new Process_Checklist__c(
            Business_Process__c = bp.Id,
            Is_Maker_Review_Completed__c = false,
            Is_Checker_Review_Completed__c = true
        );
        insert checklist;
        
        // Create checklist items
        List<Process_Checklist_Items__c> items = new List<Process_Checklist_Items__c>{
            new Process_Checklist_Items__c(
                Process_Checklist__c = checklist.Id,
                Checklist_Name__c = 'Item 1',
                Sequence__c  = 1,
                Maker_Action__c = 'No Action',
                Checker_Action__c = 'Approved',
                Checker_Rejection_Reasons__c = 'Documents Not Clear'
            ),
                new Process_Checklist_Items__c(
                    Process_Checklist__c = checklist.Id,
                    Checklist_Name__c = 'Item 2',
                    Sequence__c  = 2,
                    Maker_Action__c = 'No Action',
                    Checker_Action__c = 'Rejected',
                    Checker_Rejection_Reasons__c = 'Documents Not Clear'
                )
                };
                    insert items;
    }
    
    @isTest
    static void testGetChecklistItems() {
        RestContext.request = new RestRequest();  // allow aura call
        List<Business_Process__c> bps = [SELECT Id FROM Business_Process__c LIMIT 1];
        String bpId = bps[0].Id;
        Test.startTest();
        // Call method
        //List<Process_Checklist_Items__c> result = SPAMCStepActivato.getChecklistItems(bpId);
        Map<String, Object> result = SPAMCStepActivato.getChecklistItems(bpId);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateChecklistItems() {
        // Query an existing item
        Process_Checklist_Items__c item = [
            SELECT Id, Maker_Action__c,Sequence__c , Checker_Comments__c
            FROM Process_Checklist_Items__c
            LIMIT 1
        ];
        item.Maker_Action__c = 'No Action';
        item.Checker_Comments__c = 'Looks good';
        
        Test.startTest();
        SPAMCStepActivato.updateChecklistItems(new List<Process_Checklist_Items__c>{ item });
        SPAMCStepActivato.getPicklistValuesForChecklist();
        //SPAMCStepActivato.getPicklist('Process_Checklist_Items__c','Checker_Rejection_Reasons__c');
        Test.stopTest();
    }
    
}