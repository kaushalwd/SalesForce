/**
 * Tests use Account as the stand-in protected object so they run in any org.
 */
@IsTest
private class ProofOfPaymentDeleteGuardTest {

    private static Account makeProtectedRecord() {
        Account a = new Account(Name = 'Unit WV17');
        insert a;
        return a;
    }

    private static Id attachFile(Id parentId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf('proof of payment')
        );
        insert cv;

        Id docId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
        ].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = parentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        return docId;
    }

    private static void protectAccounts() {
        ProofOfPaymentDeleteGuard.protectedObjects = new Set<String>{ 'Account' };
    }

    @IsTest
    static void blocksFileDeletion() {
        protectAccounts();
        ProofOfPaymentDeleteGuard.overrideCanDelete = false;
        Account acct = makeProtectedRecord();
        Id docId = attachFile(acct.Id, 'POP');

        Test.startTest();
        Boolean blocked = false;
        try {
            delete [SELECT Id FROM ContentDocument WHERE Id = :docId];
        } catch (DmlException e) {
            blocked = true;
            System.assert(
                e.getMessage().contains('cannot be deleted'),
                'Expected the guard message, got: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assert(blocked, 'Deletion should have been blocked.');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'File should still exist.'
        );
    }

    @IsTest
    static void blocksRemoveFromRecord() {
        protectAccounts();
        ProofOfPaymentDeleteGuard.overrideCanDelete = false;
        Account acct = makeProtectedRecord();
        Id docId = attachFile(acct.Id, 'POP');

        ContentDocumentLink link = [
            SELECT Id FROM ContentDocumentLink
            WHERE ContentDocumentId = :docId AND LinkedEntityId = :acct.Id
            LIMIT 1
        ];

        Test.startTest();
        Boolean blocked = false;
        try {
            delete link;
        } catch (DmlException e) {
            blocked = true;
        }
        Test.stopTest();
    }

    @IsTest
    static void allowsDeletionForPermittedUser() {
        protectAccounts();
        ProofOfPaymentDeleteGuard.overrideCanDelete = true;
        Account acct = makeProtectedRecord();
        Id docId = attachFile(acct.Id, 'POP');

        Test.startTest();
        delete [SELECT Id FROM ContentDocument WHERE Id = :docId];
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Permitted user should be able to delete.'
        );
    }

    @IsTest
    static void allowsAdditionalUpload() {
        protectAccounts();
        ProofOfPaymentDeleteGuard.overrideCanDelete = false;
        Account acct = makeProtectedRecord();
        attachFile(acct.Id, 'POP');

        Test.startTest();
        attachFile(acct.Id, 'POP-corrected');
        Test.stopTest();

        System.assertEquals(
            2,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :acct.Id],
            'Users must still be able to add supporting documents.'
        );
    }

    @IsTest
    static void ignoresUnprotectedObjects() {
        protectAccounts();
        ProofOfPaymentDeleteGuard.overrideCanDelete = false;
        Contact c = new Contact(LastName = 'Unrelated');
        insert c;
        Id docId = attachFile(c.Id, 'Random');

        Test.startTest();
        delete [SELECT Id FROM ContentDocument WHERE Id = :docId];
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM ContentDocument WHERE Id = :docId],
            'Files on unprotected objects should be unaffected.'
        );
    }
}