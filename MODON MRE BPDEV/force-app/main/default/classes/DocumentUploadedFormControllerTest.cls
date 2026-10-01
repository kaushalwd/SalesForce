@isTest
public class DocumentUploadedFormControllerTest {

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

        // Create Documents
        List<Business_Process_Documents__c> docs = new List<Business_Process_Documents__c>();

        for (Integer i = 0; i < 3; i++) {
            docs.add(new Business_Process_Documents__c(
                Name = 'Doc ' + i,
                Business_Process__c = bp.Id,
                Available_to_Customer__c = false
            ));
        }
        insert docs;
    }

    @isTest
    static void testGetBusinessProcessDocuments() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        List<Business_Process_Documents__c> result =
            DocumentUploadedFormController.getBusinessProcessDocuments(bp.Id);
        Test.stopTest();

        System.assertEquals(3, result.size());
    }

    @isTest
    static void testCreateBusinessProcessDocument() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        Business_Process_Documents__c doc =
            DocumentUploadedFormController.createBussinessProcessDocument(
                bp.Id,
                'New Test Doc'
            );
        Test.stopTest();

        System.assertNotEquals(null, doc.Id);

        Business_Process_Documents__c dbDoc =
            [SELECT Id, Name FROM Business_Process_Documents__c WHERE Id = :doc.Id];

        System.assertEquals('New Test Doc', dbDoc.Name);
    }

    @isTest
    static void testUpdateBusinessProcessDocuments() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];
        List<Business_Process_Documents__c> docs =
            [SELECT Id FROM Business_Process_Documents__c LIMIT 2];

        List<Id> docIds = new List<Id>();
        for (Business_Process_Documents__c d : docs) {
            docIds.add(d.Id);
        }

        Test.startTest();
        DocumentUploadedFormController.updateBussinessProcessDocumentss(
            docIds,
            bp.Id,
            true
        );
        Test.stopTest();

        List<Business_Process_Documents__c> updated =
            [SELECT Available_to_Customer__c FROM Business_Process_Documents__c WHERE Id IN :docIds];

        for (Business_Process_Documents__c d : updated) {
            System.assertEquals(true, d.Available_to_Customer__c);
        }
    }

    @isTest
    static void testDeleteBusinessProcessDocument() {

        Business_Process_Documents__c doc =
            [SELECT Id FROM Business_Process_Documents__c LIMIT 1];

        Test.startTest();
        DocumentUploadedFormController.deleteBusinessProcessDocument(doc.Id);
        Test.stopTest();

        Integer count =
            [SELECT COUNT() FROM Business_Process_Documents__c WHERE Id = :doc.Id];

        System.assertEquals(0, count);
    }

    @isTest
    static void testGetBusinessProcessHeader() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        Business_Process__c result =
            DocumentUploadedFormController.getBusinessProcessHeader(bp.Id);
        Test.stopTest();

        System.assertEquals(bp.Id, result.Id);
    }

    @isTest
    static void testUpdateValidationErrors() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Boolean exceptionThrown = false;

        try {
            Test.startTest();
            DocumentUploadedFormController.updateBussinessProcessDocumentss(
                new List<Id>(),
                bp.Id,
                false
            );
            Test.stopTest();
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assertEquals(true, exceptionThrown);
    }
    @isTest
static void testWrappersCoverage() {

    // DocumentWrapper coverage
    DocumentUploadedFormController.DocumentWrapper dw =
        new DocumentUploadedFormController.DocumentWrapper();

    Business_Process_Documents__c doc = new Business_Process_Documents__c(
        Name = 'Wrapper Test',
        Available_to_Customer__c = true
    );

    dw.documentRecord = doc;
    dw.hasFile = true;
    dw.fileCount = 5;

    System.assert(dw.hasFile);
    System.assertEquals(5, dw.fileCount);

    // PersonWrapper coverage
    DocumentUploadedFormController.PersonWrapper pw =
        new DocumentUploadedFormController.PersonWrapper();

    pw.Id = '123';
    pw.Name = 'Test Name';
    pw.DisplayName = 'Display';
    pw.Type = 'Applicant';
    pw.SaveButtonLabel = 'Save';
    pw.SubtypeOfApplicant = 'Primary';
    pw.TypeOfApplicant = 'Owner';

    DocumentUploadedFormController.DocumentRequirement req =
        new DocumentUploadedFormController.DocumentRequirement();

    req.key = 'K1';
    req.label = 'Passport';
    req.screen = 'Upload';
    req.required = true;

    pw.requiredDocuments = new List<DocumentUploadedFormController.DocumentRequirement>{ req };

    System.assertEquals(1, pw.requiredDocuments.size());

    // FileWrapper coverage
    DocumentUploadedFormController.FileWrapper fw =
        new DocumentUploadedFormController.FileWrapper();

    fw.base64Data = 'abcd';
    fw.documentLabel = 'Passport';
    fw.fileName = 'passport.pdf';

    System.assertEquals('passport.pdf', fw.fileName);
}
}