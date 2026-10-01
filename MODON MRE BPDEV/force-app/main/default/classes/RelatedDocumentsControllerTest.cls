@isTest
public class RelatedDocumentsControllerTest {
    @testSetup
    static void setupTestData() {
        // Create test Opportunity
        Opportunity testOpp = new Opportunity(Name = 'Test Opportunity', StageName = 'New', CloseDate = Date.today(),UAE_Resident_Status__c = 'Resident',Nationality__c = 'United Arab Emirates',EmiratesIDExpiryDate__c = Date.today().addDays(365),EIDNumber__c='784-1232-1234567-4');
        insert testOpp;
        
        // Create test Lead
        Lead testLead = new Lead(
            FirstName = 'Test', 
            LastName = 'Test Lead', 
            Company = 'Test Company', 
            Status = 'Open - Not Contacted',
            LeadSource = '800-Modon',
            TradeName__c = 'Test Trade', 
            UnifiedNumber__c = '123456',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;
        
        // Create test Documents
        Documents__c doc1 = new Documents__c(Name = 'Test Document 1', Opportunity__c = testOpp.Id, Status__c = 'Uploaded');
        Documents__c doc2 = new Documents__c(Name = 'Test Document 2', Lead__c = testLead.Id, Status__c = 'Pending Upload'); 
        insert new List<Documents__c>{doc1, doc2};
        
        // Create ContentVersion (this will auto-create ContentDocument)
        ContentVersion contentVersion = new ContentVersion(
            Title = 'Test Content Version',
            PathOnClient = 'Test.pdf',
            VersionData = Blob.valueOf('Test Data'),
            FirstPublishLocationId = doc1.Id
        );
        insert contentVersion;
        
        // Fetch ContentDocument Id
        ContentDocument contentDoc = [SELECT Id FROM ContentDocument WHERE Id IN (SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'Test Content Version') LIMIT 1];
        
        // Check if ContentDocumentLink already exists before inserting
        List<ContentDocumentLink> existingLinks = [
            SELECT Id FROM ContentDocumentLink 
            WHERE LinkedEntityId = :doc1.Id AND ContentDocumentId = :contentDoc.Id
        ];
        
        if (existingLinks.isEmpty()) { // Prevent duplicate link insertion
            ContentDocumentLink contentDocLink = new ContentDocumentLink(
                LinkedEntityId = doc1.Id, 
                ContentDocumentId = contentDoc.Id,
                ShareType = 'V'
            );
            insert contentDocLink;
        }
    }
    
  /* @isTest
	static void testGetRelatedDocumentDetailWrapperForOpportunity() {
    Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];

    Test.startTest();
    List<RelatedDocumentsController.DataWrapper> result = RelatedDocumentsController.getRelatedDocumentDetailWrapper(testOpp.Id, 'Opportunity');
    Test.stopTest();

    System.assertNotEquals(0, result.size(), 'Expected documents related to the Opportunity');

    
    Boolean found = false;
    for (RelatedDocumentsController.DataWrapper doc : result) {
        if (doc.Name == 'Test Document 1') {
            found = true;
            System.assert(doc.IsDocumentUploaded, 'Document should be marked as uploaded');
            break;
        }
    }

    System.assert(found, 'Expected document "Test Document 1" not found in results');
}*/

    
    
    @isTest
    static void testGetRelatedDocumentDetailWrapperForLead() {
        //Create Test Lead
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            LeadSource = '800-Modon', 
            TradeName__c = 'Test Trade Name', 
            UnifiedNumber__c = '123456',
            ProjectInterest__c = 'Nawayef Homes'
        );
        insert testLead;

        //Create Test Document (Documents__c)
        Documents__c testDoc = new Documents__c(
            Name = 'Test Document',
            Status__c = 'Uploaded', 
            Lead__c = testLead.Id
        );
        insert testDoc;

        //Get a Library (ContentWorkspace) to store files
        ContentWorkspace library = [SELECT Id FROM ContentWorkspace LIMIT 1];

        //Create ContentVersion (First before ContentDocument)
        ContentVersion testContentVersion = new ContentVersion(
            Title = 'Test Content Document',
            PathOnClient = 'Test.pdf',
            VersionData = Blob.valueOf('Test file data'),
            FirstPublishLocationId = library.Id // Use Library instead of Lead
        );
        insert testContentVersion;

        //Query the newly created ContentDocument (Parent of ContentVersion)
        ContentDocument testContentDoc;
        List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE LatestPublishedVersionId = :testContentVersion.Id LIMIT 1];
        System.assert(!docs.isEmpty(), 'ContentDocument should be created');
        testContentDoc = docs[0];

        //Create ContentDocumentLink to Link Document with Lead
        ContentDocumentLink testLink = new ContentDocumentLink(
            LinkedEntityId = testDoc.Id, // Linking to Documents__c
            ContentDocumentId = testContentDoc.Id,
            ShareType = 'V'
        );
        insert testLink;

        //Call Method & Validate
        Test.startTest();
        List<RelatedDocumentsController.DataWrapper> result = RelatedDocumentsController.getRelatedDocumentDetailWrapper(testLead.Id, 'Lead');
        Test.stopTest();

        // Assertions
        System.assertNotEquals(0, result.size(), 'Expected at least one document linked to the Lead');

        Boolean found = false;
        for (RelatedDocumentsController.DataWrapper doc : result) {
            if (doc.Name == 'Test Document') {
                found = true;
                System.assert(doc.IsDocumentUploaded, 'Document should be marked as uploaded');
                System.assert(doc.ContentDocumentId != null, 'ContentDocumentId should not be null');
                System.assert(doc.ContentVersionId != null, 'ContentVersionId should not be null');
                break;
            }
        }
        System.assert(found, 'Expected document "Test Document" not found in results');
    }

    
    @isTest
    static void testDeleteDocumentFile() {
        ContentDocument contentDoc = [SELECT Id FROM ContentDocument LIMIT 1];
        
        Test.startTest();
        String response = RelatedDocumentsController.deleteDocumentFile(contentDoc.Id);
        Test.stopTest();
        
        System.assert(response.contains('success'), 'Expected successful deletion message');
        
        List<ContentDocument> deletedDocs = [SELECT Id FROM ContentDocument WHERE Id = :contentDoc.Id];
        System.assertEquals(0, deletedDocs.size(), 'Document should be deleted');
    }
}