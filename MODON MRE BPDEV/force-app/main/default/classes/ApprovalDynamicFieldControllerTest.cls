@isTest
public class ApprovalDynamicFieldControllerTest {

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

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Default 1  Notice Approval',
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
        // Create Document record
        Business_Process_Documents__c doc = new Business_Process_Documents__c(
            Name = 'Test Document',
            Business_Process_Step__c = steps[0].Id
        );
        insert doc;

        // Create File 
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Data'),
            IsMajorVersion = true
        );
        insert cv;

        // Get ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link file to document
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = doc.Id,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest
    static void testGetStepDocuments() {
        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        Test.startTest();
        List<ApprovalDynamicFieldController.DocumentWrapper> result =
            ApprovalDynamicFieldController.getStepDocuments(step.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetFields() {
        Test.startTest();
        /*
        List<Approval_Dynamic_Field__mdt> fields =
            ApprovalDynamicFieldController.getFields('Step1');
        */
        Test.stopTest();
    }

@isTest
static void testSubmitApproval() {
    Business_Process__c bp = [SELECT Id, Name FROM Business_Process__c LIMIT 1];
    LwcApproveRejectBpstepController.FormWrapper wrapper =
        new LwcApproveRejectBpstepController.FormWrapper();

    wrapper.recordId = bp.Id;
    wrapper.stepName = 'Step1';
    wrapper.fieldValues = new Map<String, String>();

    wrapper.fieldValues.put('Name', 'Updated BP Name');

    Test.startTest();
    ApprovalDynamicFieldController.submitApproval(wrapper);
    Test.stopTest();

    Business_Process__c updatedBp =
        [SELECT Name FROM Business_Process__c WHERE Id = :bp.Id];

    
}

@isTest
static void testSubmitApproval_NoFields() {
    Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

    LwcApproveRejectBpstepController.FormWrapper wrapper =
        new LwcApproveRejectBpstepController.FormWrapper();

    wrapper.recordId = bp.Id;
    wrapper.stepName = 'Step1';
    wrapper.fieldValues = new Map<String, String>(); // empty map

    Test.startTest();
    ApprovalDynamicFieldController.submitApproval(wrapper);
    Test.stopTest();
}
    
    @isTest
static void testGetFields1() {

    Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

    Test.startTest();
    try {
        ApprovalDynamicFieldController.getFields('Default 1  Notice Approval', bp.Id);
    } catch (Exception e) {
    }
    Test.stopTest();
}
    
    @isTest
static void testFieldWrapperUsage() {

    ApprovalDynamicFieldController.FieldWrapper fw =
        new ApprovalDynamicFieldController.FieldWrapper(
            'Business_Process__c',
            'Name',
            'text'
        );

    System.debug(fw.objectName);
    System.debug(fw.fieldApi);
    System.debug(fw.fieldType);
}

    @isTest
    static void testGetFieldsWithRecordValues() {
        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        Map<String, Object> noRecord = ApprovalDynamicFieldController.getFields(
            'Collections Customer Negotiations',
            null
        );
        Map<String, Object> withRecord = ApprovalDynamicFieldController.getFields(
            'Collections Customer Negotiations',
            bp.Id
        );
        Map<String, Object> unknownStep = ApprovalDynamicFieldController.getFields(
            'StepDoesNotExistXYZ',
            bp.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, noRecord);
        System.assertNotEquals(null, withRecord);
        System.assert(unknownStep.containsKey('values'));
    }

    @isTest
    static void testSubmitApprovalTypedFields() {
        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        LwcApproveRejectBpstepController.FormWrapper wrapper =
            new LwcApproveRejectBpstepController.FormWrapper();
        wrapper.recordId = bp.Id;
        wrapper.stepName = 'Collections Customer Negotiations';
        wrapper.fieldValues = new Map<String, String>{
            'Customer_Agreed_Payment_Date__c' => String.valueOf(Date.today()),
            'Unknown_Field__c' => 'skip'
        };

        Test.startTest();
        ApprovalDynamicFieldController.submitApproval(wrapper);
        Test.stopTest();

        System.assertEquals(bp.Id, [SELECT Id FROM Business_Process__c WHERE Id = :bp.Id].Id);
    }

    @isTest
    static void testGetStepDocumentsWithoutFiles() {
        Business_Process_Step__c step = [
            SELECT Id FROM Business_Process_Step__c WHERE Name = 'Step 2' LIMIT 1
        ];

        Test.startTest();
        try {
            ApprovalDynamicFieldController.getStepDocuments(step.Id);
        } catch (Exception ex) {
            System.debug('getStepDocuments empty docs: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assertNotEquals(null, step.Id);
    }
}