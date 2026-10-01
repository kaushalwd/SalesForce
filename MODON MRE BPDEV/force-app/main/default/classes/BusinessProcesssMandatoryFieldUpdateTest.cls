@IsTest
private class BusinessProcesssMandatoryFieldUpdateTest {

    @testSetup
    static void setupTestData() {
       Process_Flow__c testProcessFlow = new Process_Flow__c(
            Name = 'Clash Approval',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test',
            Type__c='Cost Approval'
        );
        insert testProcessFlow;

        Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
            Step_Name__c = 'Document Submission',
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
            Name = 'Document Submission',
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
        // Automation_Update__c for Booking__c
        Automation_Update__c au1 = new Automation_Update__c(
            Object_Api_Name__c = 'Booking__c',
            Field_API_Name__c = 'Status__c', 
            Field_Value__c = 'Updated via Rule',
            Status_Field_Value__c = 'Completed',
            Process_Flow_Step__c = pfs1.Id,
            Field_Type__c = 'String'
        );

        // Automation_Update__c for Unit__c
        Automation_Update__c au2 = new Automation_Update__c(
            Object_Api_Name__c = 'Unit__c',
            Field_API_Name__c = 'Unit_Status__c', 
            Field_Value__c = 'Booked', 
            Status_Field_Value__c = 'Completed',
            Process_Flow_Step__c = pfs1.Id,
            Field_Type__c = 'String'
        );
        Automation_Update__c au3 = new Automation_Update__c(
            Object_Api_Name__c = 'Business_Process__c',
            Field_API_Name__c = 'Status__c', 
            Field_Value__c = 'In Progress', 
            Status_Field_Value__c = 'Completed',
            Process_Flow_Step__c = pfs1.Id,
            Field_Type__c = 'String'
        );
        insert new List<Automation_Update__c>{au1, au2, au3};
    }

    @IsTest
    static void testPopulateMandatoryFields_Success() {
        Business_Process_Step__c bps = [
            SELECT Id, Status__c, Business_Process__c, Name 
            FROM Business_Process_Step__c 
            WHERE Name = 'Document Submission' LIMIT 1
        ];
        Business_Process_Step__c oldBPS = bps.clone(true, true, true, true);
        Map<Id, SObject> oldMap = new Map<Id, SObject>{oldBPS.Id => oldBPS};
        
        bps.Status__c = 'Completed'; 
        List<SObject> newList = new List<SObject>{bps};

        Test.startTest();
        BusinessProcesssMandatoryFieldUpdate.populateMandatoryFields(newList, oldMap);
        Test.stopTest();

        Business_Process__c updatedBP = [
            SELECT Id, Status__c 
            FROM Business_Process__c 
            WHERE Id = :bps.Business_Process__c LIMIT 1
        ];
        
        Business_Process_Step__c finalBPS = [
            SELECT Status__c
            FROM Business_Process_Step__c 
            WHERE Id = :bps.Id LIMIT 1
        ];
    }
    
    @IsTest
    static void testPopulateMandatoryFields_NoStatusChange() {
        Business_Process_Step__c bps = [SELECT Id, Status__c FROM Business_Process_Step__c LIMIT 1];
        Business_Process_Step__c oldBPS = bps.clone(true, true, true, true);
        Map<Id, SObject> oldMap = new Map<Id, SObject>{oldBPS.Id => oldBPS};
        List<SObject> newList = new List<SObject>{bps}; 

        Test.startTest();
        BusinessProcesssMandatoryFieldUpdate.populateMandatoryFields(newList, oldMap);
        Test.stopTest();      
    }
    
    @IsTest
    static void testPopulateMandatoryFields_UnrelatedStatus() {
        Business_Process_Step__c bps = [SELECT Id, Status__c, Business_Process__c FROM Business_Process_Step__c LIMIT 1];
        Business_Process_Step__c oldBPS = bps.clone(true, true, true, true);
        Map<Id, SObject> oldMap = new Map<Id, SObject>{oldBPS.Id => oldBPS};
        
        bps.Status__c = 'Unrelated Status'; 
        List<SObject> newList = new List<SObject>{bps};

        Test.startTest();
        BusinessProcesssMandatoryFieldUpdate.populateMandatoryFields(newList, oldMap); 
        Test.stopTest();     
    }
}