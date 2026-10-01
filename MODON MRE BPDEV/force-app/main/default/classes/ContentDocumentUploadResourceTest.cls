@isTest
public class ContentDocumentUploadResourceTest {
	// Unique external IDs for test records
    private static final String ACC_EXTERNAL_ID = 'ACC-001';
    private static final String CON_EXTERNAL_ID = 'CON-001';
    private static final String UNIT_EXTERNAL_ID = 'UNIT-001';
    private static final String OPP_EXTERNAL_ID = 'OPP-001';
    private static final String SO_EXTERNAL_ID = 'SO-001';

    /**
     * @description Sets up test data by creating one of each required SObject record
     * with a unique external ID. This data is available to all test methods in the class.
     */
    @testSetup
    static void makeData() {
        // Create an Account with an external ID
        Account acc = new Account(Name = 'Test Account', Q_External_Id__c = ACC_EXTERNAL_ID);
        insert acc;

        // Create a Contact with an external ID
        Contact con = new Contact(LastName = 'Test Contact', Q_External_Id__c = CON_EXTERNAL_ID);
        insert con;

        // Create a custom Unit record with an external ID
        Unit__c unit = new Unit__c(Name = 'Test Unit', Q_External_Id__c = UNIT_EXTERNAL_ID,PlotNo__c='test1',Number_of_Bedrooms__c='2',UnitClassification__c='Villa');
        insert unit;

        // Create an Opportunity with an external ID
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Q_External_Id__c = OPP_EXTERNAL_ID,
            Nationality__c= 'United Arab Emirates',
            UAE_Resident_Status__c= 'Resident',
            EmiratesIDExpiryDate__c= System.today(),
            EIDNumber__c='784-0000-0987650-6'
        );
        insert opp;

        // Create a custom SalesOrder record with an external ID
        // Note: Replace 'RequiredField__c' with any actual required fields on your SalesOrder__c object
        SalesOrder__c so = new SalesOrder__c( Q_External_Id__c = SO_EXTERNAL_ID);
        insert so;
    }

    /**
     * @description Tests the successful upload of a document to an Account record.
     */
    @isTest
    static void testUploadToAccount_Success() {
        // Find the test Account created in the setup
        Account testAccount = [SELECT Id FROM Account WHERE Q_External_Id__c = :ACC_EXTERNAL_ID LIMIT 1];
        String fileContent = 'This is a test file for an account.';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        // Simulate the REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ContentDocumentUpload/';
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        String response;
        Test.startTest();
        response = ContentDocumentUploadResource.uploadDocument('AccountTestDoc.txt', base64Data, ACC_EXTERNAL_ID, 'Account');
        Test.stopTest();

        // Verify the response indicates success
        System.assert(response.startsWith('Document uploaded successfully with ID:'), 'Response should indicate success.');

        // Verify the ContentVersion was created correctly
        ContentVersion cv = [SELECT Id, FirstPublishLocationId FROM ContentVersion WHERE Title = 'AccountTestDoc.txt' LIMIT 1];
        System.assertEquals(testAccount.Id, cv.FirstPublishLocationId, 'The document should be linked to the correct Account.');
    }

    /**
     * @description Tests the successful upload of a document to a Contact record.
     */
    @isTest
    static void testUploadToContact_Success() {
        Contact testContact = [SELECT Id FROM Contact WHERE Q_External_Id__c = :CON_EXTERNAL_ID LIMIT 1];
        String fileContent = 'This is a test file for a contact.';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        String response = ContentDocumentUploadResource.uploadDocument('ContactTestDoc.txt', base64Data, CON_EXTERNAL_ID, 'Contact');
        Test.stopTest();

        System.assert(response.startsWith('Document uploaded successfully with ID:'), 'Response should indicate success.');

        ContentVersion cv = [SELECT Id, FirstPublishLocationId FROM ContentVersion WHERE Title = 'ContactTestDoc.txt' LIMIT 1];
        System.assertEquals(testContact.Id, cv.FirstPublishLocationId, 'The document should be linked to the correct Contact.');
    }

    /**
     * @description Tests the successful upload of a document to a Unit__c record.
     */
    @isTest
    static void testUploadToUnit_Success() {
        Unit__c testUnit = [SELECT Id FROM Unit__c WHERE Q_External_Id__c = :UNIT_EXTERNAL_ID LIMIT 1];
        String fileContent = 'This is a test file for a unit.';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        String response = ContentDocumentUploadResource.uploadDocument('UnitTestDoc.txt', base64Data, UNIT_EXTERNAL_ID, 'Unit');
        Test.stopTest();

        System.assert(response.startsWith('Document uploaded successfully with ID:'), 'Response should indicate success.');

        ContentVersion cv = [SELECT Id, FirstPublishLocationId FROM ContentVersion WHERE Title = 'UnitTestDoc.txt' LIMIT 1];
        System.assertEquals(testUnit.Id, cv.FirstPublishLocationId, 'The document should be linked to the correct Unit.');
    }

    /**
     * @description Tests the successful upload of a document to an Opportunity record.
     */
    @isTest
    static void testUploadToOpportunity_Success() {
        Opportunity testOpp = [SELECT Id FROM Opportunity WHERE Q_External_Id__c = :OPP_EXTERNAL_ID LIMIT 1];
        String fileContent = 'This is a test file for an opportunity.';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        String response = ContentDocumentUploadResource.uploadDocument('OppTestDoc.txt', base64Data, OPP_EXTERNAL_ID, 'Opportunity');
        Test.stopTest();

        System.assert(response.startsWith('Document uploaded successfully with ID:'), 'Response should indicate success.');

        ContentVersion cv = [SELECT Id, FirstPublishLocationId FROM ContentVersion WHERE Title = 'OppTestDoc.txt' LIMIT 1];
        System.assertEquals(testOpp.Id, cv.FirstPublishLocationId, 'The document should be linked to the correct Opportunity.');
    }

    /**
     * @description Tests the successful upload of a document to a SalesOrder__c record.
     */
    @isTest
    static void testUploadToSalesOrder_Success() {
        SalesOrder__c testSO = [SELECT Id FROM SalesOrder__c WHERE Q_External_Id__c = :SO_EXTERNAL_ID LIMIT 1];
        String fileContent = 'This is a test file for a sales order.';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        String response = ContentDocumentUploadResource.uploadDocument('SOTestDoc.txt', base64Data, SO_EXTERNAL_ID, 'SalesOrder');
        Test.stopTest();

        System.assert(response.startsWith('Document uploaded successfully with ID:'), 'Response should indicate success.');

        ContentVersion cv = [SELECT Id, FirstPublishLocationId FROM ContentVersion WHERE Title = 'SOTestDoc.txt' LIMIT 1];
        System.assertEquals(testSO.Id, cv.FirstPublishLocationId, 'The document should be linked to the correct Sales Order.');
    }

    /**
     * @description Tests the error handling for an unsupported object type.
     */
    @isTest
    static void testUpload_UnsupportedObjectType_Failure() {
        String fileContent = 'This should fail.';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        String response = ContentDocumentUploadResource.uploadDocument('FailDoc.txt', base64Data, 'any-id', 'CustomObject__c');
        Test.stopTest();

        // Verify the specific error message for unsupported types
        System.assertEquals('Error: Unsupported object type.', response, 'Response should indicate an unsupported object type.');
    }

    /**
     * @description Tests the error handling when no record is found for the given external ID.
     */
    @isTest
    static void testUpload_RecordNotFound_Failure() {
        String fileContent = 'This should also fail.';
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf(fileContent));

        Test.startTest();
        // Use a non-existent external ID
        String response = ContentDocumentUploadResource.uploadDocument('FailDoc.txt', base64Data, 'ID-NOT-FOUND', 'Account');
        Test.stopTest();

        // The SOQL query will throw a QueryException, which is caught and returned as a generic error.
        System.assert(response.contains('Error: List has no rows for assignment to SObject'), 'Response should indicate a query error.');
    }

    /**
     * @description Tests the error handling for an invalid base64 string.
     */
    @isTest
    static void testUpload_InvalidBase64_Failure() {
        // Provide a string that is not valid base64
        String invalidBase64Data = 'this is not base64!';

        Test.startTest();
        String response = ContentDocumentUploadResource.uploadDocument('FailDoc.txt', invalidBase64Data, ACC_EXTERNAL_ID, 'Account');
        Test.stopTest();

        // The base64Decode method will throw an exception, which is caught.
        System.assert(response.contains('Error:'), 'Response should indicate a decoding error.');
    }
}