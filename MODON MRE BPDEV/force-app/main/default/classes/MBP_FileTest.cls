@IsTest
private class MBP_FileTest {
    private static void createLinkedFile(String title, Id linkedId) {
        ContentVersion ver = new ContentVersion(
            Title = title,
            PathOnClient = title,
            VersionData = Blob.valueOf('Test file content')
        );
        insert ver;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :ver.Id].ContentDocumentId;
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = linkedId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;
    }

    @IsTest
    static void testFetchAgentDocuments_fullCoverage() {
        Registration_Agent__c regAgent = new Registration_Agent__c();
        insert regAgent;

        createLinkedFile('Passport_First_Page.pdf', regAgent.Id);
        createLinkedFile('Passport_Signature_Page.pdf', regAgent.Id);
        createLinkedFile('Emirates_ID_Front.pdf', regAgent.Id);
        createLinkedFile('Emirates_ID_Back.pdf', regAgent.Id);
        createLinkedFile('POA_Document.pdf', regAgent.Id);
        createLinkedFile('Visa_Page.pdf', regAgent.Id);
        createLinkedFile('Random_Other.pdf', regAgent.Id);

        Documents__c placeholder = new Documents__c(
            Name = 'Placeholder',
            Registration_Agent__c = regAgent.Id
        );
        insert placeholder;

        createLinkedFile('Passport_First_Page_Placeholder.pdf', placeholder.Id);

        Test.startTest();
        FileService.AgentFileResult r = FileService.fetchAgentDocuments(new Set<Id>{regAgent.Id});
        Test.stopTest();

        System.assertNotEquals(null, r);
    }

    @IsTest
    static void testFetchAgentDocuments_emptySet() {
        Test.startTest();
        FileService.AgentFileResult r = FileService.fetchAgentDocuments(new Set<Id>());
        Test.stopTest();
        System.assertNotEquals(null, r);
    }
}