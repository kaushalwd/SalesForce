@IsTest
private class BusinessProcessManadatoryDocumentsTest {

    @testSetup
    static void setupData() {
        Process_Flow__c pf = new Process_Flow__c(
            Name = 'PF-Test',
            Process_Flow_Unique_Name__c = 'PF_TEST'
        );
        insert pf;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id
        );
        insert bp;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Step_Name__c = 'Document Submission',
            Process_Flow__c = pf.Id,
            Section_Number__c = 1,
            Section_Name__c = 'Section 1'
        );
        insert pfs;

        Process_Flow_Document__c pfd = new Process_Flow_Document__c(
            Name = 'Passport Copy',
            Process_Flow__c = pf.Id
        );
        insert pfd;

        Mandatory_Document__c mandDoc = new Mandatory_Document__c(
            Process_Flow_Step__c = pfs.Id,
            Process_Flow_Document__c = pfd.Id
        );
        insert mandDoc;

        Business_Process_Step__c bps = new Business_Process_Step__c(
            Business_Process__c = bp.Id,
            Name = 'Document Submission', 
            Status__c = 'Open',
            Business_Process_Steps_Name_Custom__c = 'Document Submission',
            Section_Number__c = 1,
            Section_Name__c = 'Section 1',
            Process_Flow_Step__c = pfs.Id
        );
        insert bps;
    }

    @IsTest
    static void testMissingMandatoryDocumentError() {
        
        Business_Process_Step__c step = [
            SELECT Id, Status__c
            FROM Business_Process_Step__c 
            WHERE Name = 'Document Submission'
            LIMIT 1
        ];

        step.Status__c = 'Completed';

        Test.startTest();
        try {
            update step;
            System.assert(false, 'Expected missing mandatory document validation error');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Missing mandatory document'), 'Expected missing document error');
        }
        Test.stopTest();
    }

    @IsTest
    static void testMandatoryDocumentPresentSuccess() {

        Business_Process_Step__c step = [
            SELECT Id, Business_Process__c, Name, Status__c
            FROM Business_Process_Step__c 
            WHERE Name = 'Document Submission'
            LIMIT 1
        ];

        Business_Process_Documents__c bpd = new Business_Process_Documents__c(
            Name = 'Passport Copy',
            Business_Process__c = step.Business_Process__c,
            Business_Process_Step__c = step.Id
        );
        insert bpd;

        ContentVersion cv = new ContentVersion(
            Title = 'Passport Copy',
            PathOnClient = 'PassportCopy.pdf',
            VersionData = Blob.valueOf('test file')
        );
        insert cv;

        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        insert new ContentDocumentLink(
            LinkedEntityId = bpd.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );

        step.Status__c = 'Completed';

        Test.startTest();
        update step;
        Test.stopTest();

        Business_Process_Step__c updatedStep = [
            SELECT Status__c FROM Business_Process_Step__c WHERE Id = :step.Id
        ];
        System.assertEquals('Completed', updatedStep.Status__c);
    }

    @IsTest
    static void testNoStatusChangeNoValidation() {

        Business_Process_Step__c step = [
            SELECT Id, Status__c, Business_Process__c
            FROM Business_Process_Step__c LIMIT 1
        ];

        step.Section_Name__c = 'Updated Name'; 

        Test.startTest();
        update step;
        Test.stopTest();

        Business_Process_Step__c updatedStep = [
            SELECT Section_Name__c FROM Business_Process_Step__c WHERE Id = :step.Id
        ];

        System.assertEquals('Updated Name', updatedStep.Section_Name__c);
    }

    @IsTest
    static void testStepWithNoMandatoryDocs() {

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
        update  steps[0];
        Test.stopTest();

    }
}