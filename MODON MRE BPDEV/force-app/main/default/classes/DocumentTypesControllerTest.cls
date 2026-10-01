@isTest
public class DocumentTypesControllerTest {
       private static final string SERVICE_REQUEST_RT_DEV_NAME_ADM { get { return 'Service_Request_Management_ADM'; } }

    @isTest
    static void testFetchDocandDocType() {
        Test.startTest();
                Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        
        ServiceRequest__c sr = TestDataFactory.createServiceRequest('Normal',admrRecordTypeId);
        List<DocumentTypesController.DocumentWrapper> docs = DocumentTypesController.fetchDocandDocType(sr.id, 'ServiceRequest__c');
        Test.stopTest();

        System.assertNotEquals(0, docs.size(), 'Documents should be returned');
        System.assertEquals('Passport', docs[0].docName, 'Document name should match');
    }
 @isTest
    static void testCreateContentDocumentAndLinkToCase() {
        Test.startTest();
        // Create a Document Type
        DocumentType__c docType = new DocumentType__c( Type__c = 'Passport', ShareWithCustomer__c = true, IsSystemUpload__c = false);
        insert docType;
               
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        ServiceRequest__c sr1 = TestDataFactory.createServiceRequest('Normal',admrRecordTypeId);

        // Create a Document
        Documents__c doc = new Documents__c(Name = 'Test Document', DocumentType__c = docType.Id, Service_Request__c = sr1.Id, Status__c = 'uploaded');
        insert doc;
       
        
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test Data'));
                Id contentDocId = DocumentTypesController.createContentDocumentAndLinkToCase(doc.Id, 'TestFile.pdf', base64Data, 'TestPath');

       
        Test.stopTest();

        System.assertNotEquals(null, contentDocId, 'Content Document should be created and linked');
    }
    
        @isTest
    static void testCreateContentVersion() {
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test Data'));
        
        Test.startTest();
        ContentVersion cv = DocumentTypesController.createContentVersion(null, 'New Version', base64Data, 'NewPath');
        Test.stopTest();
    }
    @isTest
    static void testCreateContentDocumentAndLinkToCase_InvalidData() {
        Test.startTest();
        try {
            Id contentVersionId = DocumentTypesController.createContentDocumentAndLinkToCase(null, null, null, null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    @isTest
    static void DocumentTypeController() {
        Test.startTest();
        try{
        // Create a Document Type
        DocumentType__c docType = new DocumentType__c( Type__c = 'Passport', ShareWithCustomer__c = true, IsSystemUpload__c = false,RecordTypeDevName__c =SERVICE_REQUEST_RT_DEV_NAME_ADM);
        insert docType;
               
        Id admrRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        ServiceRequest__c sr1 = TestDataFactory.createServiceRequest('Normal',admrRecordTypeId);
            List<SObject> newList =new List<SObject>();
            newList.add(sr1);
		DocumentTypeController.creatingDocment(newList,'Service Request');
             //ServiceRequestTaskController.justIncrement();
            DocumentTypeController.justIncrement();
        } catch (Exception e) {
        }
        Test.stopTest();
    }
    
}