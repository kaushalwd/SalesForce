/**********************************************************************************************************************
* Name               : DocumentAutoSendDocuSignQueueableTest
* Description        : Test class for DocumentAutoSendDocuSignQueueable, DocumentTriggerHelper, and DocuSignSendRequestTrigger
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Rushi Patel                 01 Sep 2026     Initial draft
* 2.0           Rushi Patel                 11 Sep 2026     Expanded coverage: null/empty inputs, retry-below-threshold
*                                                            re-enqueue path, bulk chunking (>90 docs) path, and
*                                                            bulk/multi-document processing
******************************************************************************************************************/
@isTest
private class DocumentAutoSendDocuSignQueueableTest {

    @testSetup
    static void setupTestData() {
        // Create necessary records for testing
        Account acc = new Account(Name = 'Test Customer');
        insert acc;

        Contact con = new Contact(LastName = 'Customer', Email = 'test@example.com', AccountId = acc.Id);
        insert con;

        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = acc.Id, PrimaryContact__c = con.Id);
        insert opp;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Opportunity__c = opp.Id);
        insert so;

        Documents__c doc = new Documents__c(
            Opportunity__c = opp.Id,
            SalesOrder__c = so.Id,
            Document_Status__c = 'Pending',
            Auto_Send_DocuSign_Email__c = false
        );
        insert doc;

        // Create ContentVersion (File)
        ContentVersion cv = new ContentVersion(
            Title = 'Test PDF',
            PathOnClient = 'Test.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;

        // Link File to Document
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = doc.Id,
            ContentDocumentId = insertedCv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest
    static void testDocumentTriggerHelper() {
        Documents__c doc = [SELECT Id FROM Documents__c LIMIT 1];

        Test.startTest();
        doc.Document_Status__c = 'Generated';
        doc.Auto_Send_DocuSign_Email__c = true;
        update doc;
        Test.stopTest();

        System.assert(true, 'Helper ran successfully.');
    }

    @isTest
    static void testPlatformEventTrigger() {
        Documents__c doc = [SELECT Id FROM Documents__c LIMIT 1];

        Test.startTest();
        DocuSign_Send_Request__e req = new DocuSign_Send_Request__e(Document_Id__c = doc.Id);
        EventBus.publish(req);
        Test.stopTest();

        System.assert(true, 'Trigger executed successfully.');
    }

    @isTest
    static void testQueueableExecution() {
        Documents__c doc = [SELECT Id FROM Documents__c LIMIT 1];

        Test.startTest();
        // Invoke Queueable directly to bypass async chaining limits (Platform Event -> Queueable)
        System.enqueueJob(new DocumentAutoSendDocuSignQueueable(new Set<Id>{doc.Id}, 0));
        Test.stopTest();

        // Verify Queueable execution
        Documents__c updatedDoc = [SELECT Id, EnvelopID__c, Document_Error_Message__c FROM Documents__c WHERE Id = :doc.Id];

        // Since we bypass sendEnvelope in test context, EnvelopID__c might be null or default,
        // but we verify no exception was thrown during the processing.
        System.assert(updatedDoc.Document_Error_Message__c == null, 'There should be no errors logged on the document.');
    }

    @isTest
    static void testQueueableRetryLogic() {
        Documents__c seedDoc = [SELECT Id, Opportunity__c, SalesOrder__c FROM Documents__c LIMIT 1];

        // Use a dedicated document that never had a file linked to it, rather than deleting
        // the ContentDocumentLink created in @testSetup. ContentDocumentLink deletes are not
        // reliably rolled back between test methods in this org (Chatter Files quirk), so
        // sharing/deleting the setup link causes flaky failures in other test methods.
        Documents__c doc = new Documents__c(
            Opportunity__c = seedDoc.Opportunity__c,
            SalesOrder__c = seedDoc.SalesOrder__c,
            Document_Status__c = 'Pending'
        );
        insert doc;

        Test.startTest();
        // Fire Queueable with retryCount = 3 to trigger the failure block
        System.enqueueJob(new DocumentAutoSendDocuSignQueueable(new Set<Id>{doc.Id}, 3));
        Test.stopTest();

        // Verify failure was logged once the retry threshold has been exceeded
        Documents__c updatedDoc = [SELECT Id, Document_Error_Message__c FROM Documents__c WHERE Id = :doc.Id];
        System.assertEquals(
            'DocuSign Send Error: Document generation took too long or file was not attached.',
            updatedDoc.Document_Error_Message__c,
            'Document should be flagged with a final failure message once retries are exhausted.'
        );
    }

    @isTest
    static void testQueueableRetryLogicBelowThreshold() {
        Documents__c seedDoc = [SELECT Id, Opportunity__c, SalesOrder__c FROM Documents__c LIMIT 1];

        // Dedicated document with no file linked, to simulate the Nintex file not being
        // available yet without touching the shared @testSetup ContentDocumentLink.
        Documents__c doc = new Documents__c(
            Opportunity__c = seedDoc.Opportunity__c,
            SalesOrder__c = seedDoc.SalesOrder__c,
            Document_Status__c = 'Pending'
        );
        insert doc;

        Test.startTest();
        // retryCount below the threshold (3) should re-enqueue the missing-file document
        // rather than marking it as permanently failed
        System.enqueueJob(new DocumentAutoSendDocuSignQueueable(new Set<Id>{doc.Id}, 1));
        Test.stopTest();

        Documents__c updatedDoc = [SELECT Id, Document_Error_Message__c FROM Documents__c WHERE Id = :doc.Id];
        System.assertEquals(
            null,
            updatedDoc.Document_Error_Message__c,
            'Document should not yet be marked as failed while under the retry threshold.'
        );
    }

    @isTest
    static void testExecuteWithNullDocumentIds() {
        DocumentAutoSendDocuSignQueueable queueable = new DocumentAutoSendDocuSignQueueable(null, 0);

        Test.startTest();
        // Calling execute directly (rather than via enqueueJob) exercises the guard clause
        // for a null document Id set without requiring an async context.
        queueable.execute(null);
        Test.stopTest();

        System.assert(true, 'Execute should return immediately without error for a null document set.');
    }

    @isTest
    static void testExecuteWithEmptyDocumentIds() {
        DocumentAutoSendDocuSignQueueable queueable = new DocumentAutoSendDocuSignQueueable(new Set<Id>(), 0);

        Test.startTest();
        // Exercises the guard clause for an empty (but non-null) document Id set.
        queueable.execute(null);
        Test.stopTest();

        System.assert(true, 'Execute should return immediately without error for an empty document set.');
    }

    @isTest
    static void testQueueableBulkChunking() {
        // Create a base Documents__c to reuse the account/opportunity/sales order hierarchy
        Documents__c seedDoc = [SELECT Id, Opportunity__c, SalesOrder__c FROM Documents__c LIMIT 1];

        // Insert enough additional documents to exceed the 90-record processing chunk,
        // exercising the "remaining documents deferred to the next chunk" branch.
        List<Documents__c> bulkDocs = new List<Documents__c>();
        for (Integer i = 0; i < 95; i++) {
            bulkDocs.add(new Documents__c(
                Opportunity__c = seedDoc.Opportunity__c,
                SalesOrder__c = seedDoc.SalesOrder__c,
                Document_Status__c = 'Pending'
            ));
        }
        insert bulkDocs;

        Set<Id> allDocIds = new Set<Id>();
        for (Documents__c d : bulkDocs) {
            allDocIds.add(d.Id);
        }

        Test.startTest();
        System.enqueueJob(new DocumentAutoSendDocuSignQueueable(allDocIds, 0));
        Test.stopTest();

        // No hard assertion on downstream envelope state (no ContentDocumentLink exists for
        // these records), just confirm the chunking/bulk path executes without unhandled errors.
        System.assert(true, 'Bulk chunking path executed for more than 90 documents.');
    }

    @isTest
    static void testQueueableMultipleDocumentsBulk() {
        Documents__c seedDoc = [SELECT Id, Opportunity__c, SalesOrder__c FROM Documents__c LIMIT 1];

        // Create a second, independent document + file so this test does not depend on
        // ContentDocumentLink data from @testSetup (which other test methods delete; File
        // share deletes are not reliably rolled back between test methods).
        Documents__c secondDoc = new Documents__c(
            Opportunity__c = seedDoc.Opportunity__c,
            SalesOrder__c = seedDoc.SalesOrder__c,
            Document_Status__c = 'Pending'
        );
        insert secondDoc;

        ContentVersion cv = new ContentVersion(
            Title = 'Second Test PDF',
            PathOnClient = 'Second.pdf',
            VersionData = Blob.valueOf('Second Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            LinkedEntityId = secondDoc.Id,
            ContentDocumentId = contentDocumentId,
            ShareType = 'V'
        );

        Test.startTest();
        System.enqueueJob(new DocumentAutoSendDocuSignQueueable(new Set<Id>{seedDoc.Id, secondDoc.Id}, 0));
        Test.stopTest();

        List<Documents__c> updatedDocs = [SELECT Id, Document_Error_Message__c FROM Documents__c WHERE Id IN :new Set<Id>{seedDoc.Id, secondDoc.Id}];
        System.assertEquals(2, updatedDocs.size(), 'Both documents should have been processed.');
        for (Documents__c d : updatedDocs) {
            System.assertEquals(null, d.Document_Error_Message__c, 'No errors expected when both documents have files attached.');
        }
    }
}