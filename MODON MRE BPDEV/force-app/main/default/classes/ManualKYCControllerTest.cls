/**********************************************************************************************************************
* Name               : ManualKYCControllerTest
* Description        : Test class for ManualKYCController. Validates file renaming, fetching available files, and
*                      approval logic across every object the feature is enabled on (Account and Contact).
* Usage              : Executed via Apex Test Execution
* Created By         : Rushi Patel - Horizontal Digital
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date                  Comment
* 1.0           Rushi Patel                 27 Aug 2026           Initial draft
* 1.1           Rushi Patel                 21 September 2026     Extended to cover Account + Contact
******************************************************************************************************************/
@isTest
public class ManualKYCControllerTest {

    /**
     * @description Sets up standard test data required for all test methods.
     * Creates an Account and a Contact, each with its own ContentDocument attached.
     */
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test KYC Account');
        insert acc;

        Contact con = new Contact(LastName = 'Test KYC Contact');
        insert con;

        // One ContentVersion per record - each auto-generates its own ContentDocument
        List<ContentVersion> versions = new List<ContentVersion>{
            buildVersion('Test Document Account'),
            buildVersion('Test Document Contact')
        };
        insert versions;

        Map<String, Id> docByTitle = new Map<String, Id>();
        for (ContentVersion cv : [SELECT Title, ContentDocumentId FROM ContentVersion WHERE Id IN :versions]) {
            docByTitle.put(cv.Title, cv.ContentDocumentId);
        }

        insert new List<ContentDocumentLink>{
            buildLink(acc.Id, docByTitle.get('Test Document Account')),
            buildLink(con.Id, docByTitle.get('Test Document Contact'))
        };
    }

    private static ContentVersion buildVersion(String title) {
        return new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf('Test Content Data For KYC'),
            IsMajorVersion = true
        );
    }

    private static ContentDocumentLink buildLink(Id linkedEntityId, Id contentDocumentId) {
        return new ContentDocumentLink(
            LinkedEntityId = linkedEntityId,
            ContentDocumentId = contentDocumentId,
            ShareType = 'V'
        );
    }

    /**
     * @description Returns the ContentDocument attached to the given record in test setup.
     */
    private static Id docIdFor(Id recordId) {
        return [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId LIMIT 1].ContentDocumentId;
    }

    /**
     * @description Pulls a valid restricted-picklist value off whichever object is under test,
     * so the DML cannot fail with INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST.
     */
    private static String firstReasonValue(SObjectType targetType) {
        Schema.DescribeFieldResult dfr = targetType.getDescribe()
            .fields.getMap()
            .get('KYC_Manual_Reason__c')
            .getDescribe();
        List<Schema.PicklistEntry> entries = dfr.getPicklistValues();
        return entries.isEmpty() ? null : entries[0].getValue();
    }

    private static Id accountId() {
        return [SELECT Id FROM Account LIMIT 1].Id;
    }

    private static Id contactId() {
        return [SELECT Id FROM Contact LIMIT 1].Id;
    }

    /**
     * @description Tests the renaming of a freshly uploaded file to ensure it adopts the "Manual KYC - [Date] [Time]" format.
     * File renaming is object-independent, so a single pass is enough.
     */
    @isTest
    static void testRenameUploadedFile() {
        Id docId = docIdFor(accountId());

        Test.startTest();
        Map<String, String> result = ManualKYCController.renameUploadedFile(docId);
        Test.stopTest();

        System.assert(result.get('label').contains('Manual KYC -'), 'The returned label should be properly renamed.');

        ContentDocument updatedDoc = [SELECT Title FROM ContentDocument WHERE Id = :docId LIMIT 1];
        System.assert(updatedDoc.Title.contains('Manual KYC -'), 'The ContentDocument title in the database should be updated.');
    }

    /**
     * @description Tests fetching reusable files from an Account.
     */
    @isTest
    static void testGetAvailableKYCFilesForAccount() {
        assertAvailableFileFound(accountId());
    }

    /**
     * @description Tests fetching reusable files from a Contact.
     */
    @isTest
    static void testGetAvailableKYCFilesForContact() {
        assertAvailableFileFound(contactId());
    }

    private static void assertAvailableFileFound(Id recordId) {
        Id docId = docIdFor(recordId);

        // Pre-condition: rename it so it matches the expected pattern for "Available" files
        ManualKYCController.renameUploadedFile(docId);

        Test.startTest();
        List<Map<String, String>> files = ManualKYCController.getAvailableKYCFiles(recordId);
        Test.stopTest();

        System.assertEquals(1, files.size(),
            'Should find 1 available file for ' + recordId.getSObjectType() + ' since it matches the naming convention and has not been submitted.');
    }

    /**
     * @description Tests the final submission step against an Account.
     */
    @isTest
    static void testSubmitForApprovalForAccount() {
        assertSubmitUpdatesRecord(accountId());
    }

    /**
     * @description Tests the final submission step against a Contact.
     */
    @isTest
    static void testSubmitForApprovalForContact() {
        assertSubmitUpdatesRecord(contactId());
    }

    private static void assertSubmitUpdatesRecord(Id recordId) {
        SObjectType targetType = recordId.getSObjectType();
        Id docId = docIdFor(recordId);
        String validReason = firstReasonValue(targetType);

        Test.startTest();
        // The Approval Process submission is bypassed in test context, so this will not roll back
        ManualKYCController.submitForApproval(recordId, validReason, 'Please expedite', docId);
        Test.stopTest();

        // Re-read the record dynamically so the same assertion serves every supported object
        String soql = 'SELECT KYC_Manual_Reason__c, Manual_KYC_Comment__c FROM '
            + targetType.getDescribe().getName() + ' WHERE Id = :recordId LIMIT 1';
        SObject updated = Database.query(soql);

        System.assertEquals(validReason, (String) updated.get('KYC_Manual_Reason__c'),
            'KYC Reason should be updated on the ' + targetType + '.');
        System.assertEquals('Please expedite', (String) updated.get('Manual_KYC_Comment__c'),
            'KYC Comment should be updated on the ' + targetType + '.');

        ContentDocument updatedDoc = [SELECT Title FROM ContentDocument WHERE Id = :docId LIMIT 1];
        System.assert(updatedDoc.Title.contains('For Approval'), 'The document title should have "For Approval" appended.');
    }

    /**
     * @description An object with no entry in APPROVAL_PROCESS_BY_SOBJECT should be rejected rather than
     * silently writing to fields that may not exist there.
     */
    @isTest
    static void testSubmitForApprovalRejectsUnsupportedObject() {
        // A well-formed Id is enough to resolve the SObjectType - the guard fires before any DML,
        // so there is no need to insert a record and trip that object's validation rules.
        Id unsupportedId = Id.valueOf(Lead.SObjectType.getDescribe().getKeyPrefix() + '000000000000');

        Boolean threw = false;
        Test.startTest();
        try {
            ManualKYCController.submitForApproval(unsupportedId, 'Technical Issue', 'Should not work', null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Submitting an object outside the configured map should throw.');
    }

    /**
     * @description Tests the Flow invocable renaming an Account file from "For Approval" to "Approved".
     */
    @isTest
    static void testUpdateDocumentNameOnApprovalForAccount() {
        assertDocumentRenamedOnOutcome(accountId(), '- Approved');
    }

    /**
     * @description Tests the Flow invocable renaming a Contact file from "For Approval" to "Rejected".
     */
    @isTest
    static void testUpdateDocumentNameOnApprovalForContact() {
        assertDocumentRenamedOnOutcome(contactId(), '- Rejected');
    }

    private static void assertDocumentRenamedOnOutcome(Id recordId, String outcome) {
        Id docId = docIdFor(recordId);

        // Pre-condition: mimic a file currently sitting in an approval process
        update new ContentDocument(Id = docId, Title = 'Manual KYC - 27-08-2026 - For Approval');

        ManualKYCController.KYCApprovalRequest req = new ManualKYCController.KYCApprovalRequest();
        req.recordId = recordId;
        req.status = outcome;

        Test.startTest();
        ManualKYCController.updateDocumentNameOnApproval(new List<ManualKYCController.KYCApprovalRequest>{req});
        Test.stopTest();

        ContentDocument updatedDoc = [SELECT Title FROM ContentDocument WHERE Id = :docId LIMIT 1];
        System.assert(updatedDoc.Title.contains(outcome),
            'The document title should be successfully updated to ' + outcome + ' for ' + recordId.getSObjectType() + '.');
    }

    /**
     * @description An empty request list should exit cleanly and leave pending files untouched.
     */
    @isTest
    static void testUpdateDocumentNameOnApprovalHandlesEmptyInput() {
        Id docId = docIdFor(accountId());
        String pendingTitle = 'Manual KYC - 27-08-2026 - For Approval';
        update new ContentDocument(Id = docId, Title = pendingTitle);

        Test.startTest();
        ManualKYCController.updateDocumentNameOnApproval(new List<ManualKYCController.KYCApprovalRequest>());
        Test.stopTest();

        ContentDocument untouchedDoc = [SELECT Title FROM ContentDocument WHERE Id = :docId LIMIT 1];
        System.assertEquals(pendingTitle, untouchedDoc.Title,
            'A file awaiting approval should be left alone when there is nothing to rename.');
    }
}