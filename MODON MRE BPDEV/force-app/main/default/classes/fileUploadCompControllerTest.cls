@isTest
public class fileUploadCompControllerTest {

    @testSetup
    static void setupData() {
        
         Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Alias = 'testusr',
            Email = 'testuser@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert u;

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
            Name = 'Step 1',
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs1.Id, 
            Sequence__c = 1,
            Status__c = 'Not Actioned',
            OwnerId = u.Id,
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
            OwnerId = u.Id,
            Business_Process_Steps_Name_Custom__c='test2',
            Section_Number__c=2,
            section_Name__c='test2'
        ));
        insert steps;

        // Process Flow Document
        Process_Flow_Document__c doc = new Process_Flow_Document__c(
            Name = 'Doc A',
            sequence__c = 1,
            Document_Description__c = 'Test Description',
            isAutoGen__c = false,
            Process_Flow__c=testProcessFlow.Id
        );
        insert doc;

        // Business Process Document
        Business_Process_Documents__c bpd = new Business_Process_Documents__c(
            Name = 'BP Doc',
            Business_Process__c = bp.Id,
            Business_Process_Step__c = steps[0].Id,
            Process_Flow_Document__c = doc.Id
        );
        insert bpd;

        // Mandatory Document (makes it required)
        Mandatory_Document__c md = new Mandatory_Document__c(
            Process_Flow_Step__c = pfs1.Id,
            Process_Flow_Document__c = doc.Id
        );
        insert md;

        // Create a File (ContentVersion)
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Test Content')
        );
        insert cv;

        // Query ContentDocumentId
        cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        // Link file to Business Process Document
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = bpd.Id,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest
    static void testGetDocumentsWithFiles() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];

        Test.startTest();
        List<fileUploadCompController.DocumentWrapper> result =
            fileUploadCompController.getDocumentsWithFiles(bp.Id);
        Test.stopTest();

    }

    @isTest
    static void testNoDocuments() {

        Test.startTest();
        List<fileUploadCompController.DocumentWrapper> result =
            fileUploadCompController.getDocumentsWithFiles(null);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }
}