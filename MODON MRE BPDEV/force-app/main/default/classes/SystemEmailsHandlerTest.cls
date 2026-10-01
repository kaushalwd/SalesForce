@isTest
public class SystemEmailsHandlerTest {

    private static void useExistingOrgWideEmailForTests() {
        List<OrgWideEmailAddress> addresses = [
            SELECT DisplayName FROM OrgWideEmailAddress WHERE IsVerified = true LIMIT 1
        ];
        System.assert(!addresses.isEmpty(), 'At least one verified Org-Wide Email must exist in the org');
        SystemEmailsHandler.orgWideEmailDisplayName = addresses[0].DisplayName;
    }

    private static Account getVipPersonAccount() {
        Map<String, Id> testData = TestDataFactory.createTestData();
        Account personAccount = [
            SELECT Id, PersonContactId, PersonEmail
            FROM Account
            WHERE Id = :testData.get('vipPersonAccount')
        ];
        System.assertNotEquals(null, personAccount.PersonContactId, 'Person Account must have a contact for the email template');
        System.assertNotEquals(null, personAccount.PersonEmail, 'Person Account must have an email');
        return personAccount;
    }

    private static Receipt__c createPersonAccountReceipt() {
        Receipt__c receipt = new Receipt__c(Account__c = getVipPersonAccount().Id);
        insert receipt;
        return receipt;
    }

    private static void attachPdfToReceipt(Id receiptId, String fileName) {
        ContentVersion cv = new ContentVersion(
            Title = fileName,
            PathOnClient = fileName,
            VersionData = Blob.valueOf('test receipt pdf'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = receiptId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    @isTest
    static void testSendReceiptApprovalEmailWithAttachment() {
        useExistingOrgWideEmailForTests();
        Receipt__c receipt = createPersonAccountReceipt();
        attachPdfToReceipt(receipt.Id, 'PaymentAck.pdf');

        Test.startTest();
        SystemEmailsHandler.sendReceiptApprovalEmail(new List<String>{ receipt.Id });
        Integer emailsSent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailsSent, 'Receipt approval email should be sent');
    }

    @isTest
    static void testSendReceiptApprovalEmailWithoutAttachment() {
        useExistingOrgWideEmailForTests();
        Receipt__c receipt = createPersonAccountReceipt();

        Test.startTest();
        SystemEmailsHandler.sendReceiptApprovalEmail(new List<String>{ receipt.Id });
        Integer emailsSent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailsSent, 'Email should send even when the Receipt has no files');
    }

    @isTest
    static void testSendReceiptApprovalEmailBulkReceipts() {
        useExistingOrgWideEmailForTests();
        Account personAccount = getVipPersonAccount();
        List<Receipt__c> receipts = new List<Receipt__c>{
            new Receipt__c(Account__c = personAccount.Id),
            new Receipt__c(Account__c = personAccount.Id)
        };
        insert receipts;
        attachPdfToReceipt(receipts[0].Id, 'ReceiptOne.pdf');
        attachPdfToReceipt(receipts[1].Id, 'ReceiptTwo.pdf');

        Test.startTest();
        SystemEmailsHandler.sendReceiptApprovalEmail(new List<String>{ receipts[0].Id, receipts[1].Id });
        Integer emailsSent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailsSent, 'Multiple receipts should send in one email invocation');
    }

    @isTest
    static void testSendReceiptApprovalEmailNullList() {
        Test.startTest();
        SystemEmailsHandler.sendReceiptApprovalEmail(null);
        Integer emailsSent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(0, emailsSent, 'Null receipt list should not send an email');
    }

    @isTest
    static void testSendReceiptApprovalEmailEmptyList() {
        Test.startTest();
        SystemEmailsHandler.sendReceiptApprovalEmail(new List<String>());
        Integer emailsSent = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(0, emailsSent, 'Empty receipt list should not send an email');
    }
}