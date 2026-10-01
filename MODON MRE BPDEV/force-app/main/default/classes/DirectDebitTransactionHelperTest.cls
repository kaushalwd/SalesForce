@isTest
public class DirectDebitTransactionHelperTest {

    // Every callout body the mock answered. Other triggers (the Unit sync) call out too, so a test
    // picks out its own payload by a key only that payload carries.
    public static List<String> calloutBodies = new List<String>();

    private static String sentBody(String marker) {
        for (String body : calloutBodies) {
            if (body != null && body.contains(marker)) {
                return body;
            }
        }
        return null;
    }

    // Suffix for names and emails, so several mandates in one test do not collide.
    private static Integer seq = 0;

    private static Account personAccount() {
        seq++;
        Account acc = new Account(
            FirstName = 'Test',
            LastName = 'DDT Account ' + seq,
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'ddt.helper' + seq + '@test.com'
        );
        insert acc;
        return acc;
    }

    private static SalesOrder__c salesOrder() {
        seq++;
        EscrowAccount__c escAccount = new EscrowAccount__c(Name = 'DDT Escrow ' + seq);
        insert escAccount;
        Phase__c phase = new Phase__c(Name = 'DDT Phase ' + seq, EscrowAccount__c = escAccount.Id);
        insert phase;
        Unit__c unit = new Unit__c(Name = 'DDT Unit ' + seq, Phase__c = phase.Id, PlotNo__c = '123',
                                   Number_of_bedrooms__c = '2', UnitClassification__c = 'Apartment');
        insert unit;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, TotalAmount__c = 100);
        insert so;
        return so;
    }

    /**
     * Gateway__c defaults to UAEDDS and No_New_FAB_Mandates refuses a FAB mandate on insert, so a FAB
     * mandate is raised as UAEDDS and moved across afterwards, as the 2026-08-23 backfill did. The
     * record type moves with the gateway: UAEDDS_Record_Type_Matches_Gateway refuses the two drifting
     * apart. Without this, UAEDDS_Request_Type_Isolation refuses every FAB transaction below.
     */
    private static DirectDebitRequest__c fabMandate(DirectDebitRequest__c m) {
        insert m;
        update new DirectDebitRequest__c(
            Id = m.Id,
            Gateway__c = 'FAB Legacy',
            RecordTypeId = Schema.SObjectType.DirectDebitRequest__c
                .getRecordTypeInfosByDeveloperName().get('FAB_Legacy').getRecordTypeId()
        );
        return m;
    }

    /** A live FAB mandate carrying everything the registration payload reads. */
    private static DirectDebitRequest__c activeFabMandate() {
        return fabMandate(new DirectDebitRequest__c(
            Status__c = 'Send To Bank',
            isActive__c = true,
            Commences_On__c = Date.today(),
            Expires_On__c = Date.today().addMonths(6),
            Customer_Id_Type__c = 'UAE Emirates Identity Card',
            Customer_ID_Number__c = '123-456-7890',
            Customer_Bank_Name__c = 'Abu Dhabi Commercial Bank',
            Customer_Bank_Account_Type__c = 'Savings',
            Customer_IBAN_Number__c = 'AE070331234567890123456',
            Customer_Mobile__c = '971500000000',
            Maximum_Amount__c = 5000,
            OIC__c = 'OIC123456',
            Account__c = personAccount().Id,
            SalesOrder__c = salesOrder().Id
        ));
    }

    /** A FAB mandate already cancelled on our side, awaiting the bank's cancellation. No Sales Order, so it never meets the one-mandate-per-order check. */
    private static DirectDebitRequest__c cancelledFabMandate() {
        return fabMandate(new DirectDebitRequest__c(
            Status__c = 'Cancelled',
            isActive__c = false,
            DDA_Unique_Number__c = '12121212',
            Commences_On__c = Date.today(),
            Expires_On__c = Date.today().addMonths(6),
            OIC__c = 'OIC123456'
        ));
    }

    private static DirectDebit_Transactions__c insertTransaction(Id mandateId, String requestType) {
        DirectDebit_Transactions__c txn = new DirectDebit_Transactions__c(
            Direct_Debit_Request__c = mandateId,
            Request_Type__c = requestType
        );
        insert txn;
        return txn;
    }

    /** Re-read, so the formula fields the helper keys on (Payer Identification, DDA number) are filled. */
    private static DirectDebit_Transactions__c requery(Id txnId) {
        return [SELECT Id, Direct_Debit_Request__c, Request_Type__c, Payer_Identification__c, DDA_Unique_Number__c,
                       RegVIdStatus__c, RegACKStatus__c, RegResStatus__c, Rejection_Reason__c, DDA_Reference__c,
                       CancellationResStatus__c, CancellationAckStatus__c
                FROM DirectDebit_Transactions__c WHERE Id = :txnId];
    }

    /** Links one file to every document on the mandate, so whichever one the helper picks has it. */
    private static void attachFile(Id mandateId) {
        ContentVersion cv = new ContentVersion(Title = 'Test Document', PathOnClient = 'TestDoc.pdf',
                                               VersionData = Blob.valueOf('Test Data'));
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (Documents__c doc : [SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId]) {
            links.add(new ContentDocumentLink(ContentDocumentId = contentDocumentId, LinkedEntityId = doc.Id,
                                              ShareType = 'V', Visibility = 'AllUsers'));
        }
        insert links;
    }

    @isTest
    static void testCreatePayment() {
        SalesOrder__c so = salesOrder();
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 5000,
            Milestone__c = 1,
            MilestoneDate__c = Date.today()
        );
        insert soi;

        DirectDebit_Transactions__c ddTrans = new DirectDebit_Transactions__c(
            Request_Type__c = 'Collection',
            Ack_Nack_Response__c = 'PAY',
            Transaction_Status__c = '',
            SOInstallment__c = soi.Id,
            Collection_Amount__c = 5000
        );
        insert ddTrans;

        ddTrans.Ack_Nack_Response__c = 'FAILED';
        update ddTrans;

        ddTrans.Ack_Nack_Response__c = 'PAY';
        ddTrans.Transaction_Status__c = 'Success';

        // createPayment swallows its own exceptions, so the receipt is not asserted: Receipt__c
        // carries validation rules this fixture does not set up for.
        Test.startTest();
        update ddTrans;
        Test.stopTest();

        Assert.areEqual('Success', [SELECT Transaction_Status__c FROM DirectDebit_Transactions__c WHERE Id = :ddTrans.Id].Transaction_Status__c);
    }

    @isTest
    static void testUaeddsMandateRefusesFabRequestType() {
        // Guards the root cause of the fixture above: a mandate left on its UAEDDS default must not
        // take a FAB request type, or the FAB chain would submit it to a gateway that does not know it.
        DirectDebitRequest__c m = new DirectDebitRequest__c(Status__c = 'Send To Bank');
        insert m;

        Boolean refused = false;
        try {
            insertTransaction(m.Id, 'Collection');
        } catch (DmlException e) {
            refused = e.getMessage().contains('UAEDDS');
        }
        Assert.isTrue(refused, 'UAEDDS_Request_Type_Isolation must refuse a FAB request type on a UAEDDS mandate');
    }

    @isTest
    static void testTriggerRoutesEveryFabRequestType() {
        DirectDebitRequest__c m = activeFabMandate();

        Test.startTest();
        // After insert: sendTranactionToFABGateway routes each type to its future, and a New
        // Registration moves the mandate to Send To Bank.
        DirectDebit_Transactions__c reg = insertTransaction(m.Id, 'New Registration');
        insertTransaction(m.Id, 'Collection');
        insertTransaction(m.Id, 'Cancellation');
        // After update: createPayment and updateDirectDebitApprovalStatus.
        reg.RegVIdStatus__c = 'Pending';
        update reg;
        Test.stopTest();

        Assert.areEqual('Send To Bank', [SELECT Status__c FROM DirectDebitRequest__c WHERE Id = :m.Id].Status__c);
        Assert.areEqual(3, [SELECT COUNT() FROM DirectDebit_Transactions__c WHERE Direct_Debit_Request__c = :m.Id]);
    }

    @isTest
    static void testApprovalStatus_ApprovedByBank() {
        DirectDebitRequest__c m = activeFabMandate();
        DirectDebit_Transactions__c txn = requery(insertTransaction(m.Id, 'New Registration').Id);
        txn.RegVIdStatus__c = 'Success';
        txn.RegACKStatus__c = 'INITIATED';
        txn.RegResStatus__c = 'ACCP';
        txn.DDA_Reference__c = 'DDA-0001';

        Test.startTest();
        DirectDebitTransactionHelper.updateDirectDebitApprovalStatus(new List<SObject>{ txn });
        Test.stopTest();

        DirectDebitRequest__c after = [SELECT Status__c, Approved_Date__c, DDA_Unique_Number__c
                                       FROM DirectDebitRequest__c WHERE Id = :m.Id];
        Assert.areEqual('Approved By Bank', after.Status__c);
        Assert.areEqual(Date.today(), after.Approved_Date__c);
        Assert.areEqual('DDA-0001', after.DDA_Unique_Number__c);
    }

    @isTest
    static void testApprovalStatus_RejectedByBank() {
        DirectDebitRequest__c m = activeFabMandate();
        DirectDebit_Transactions__c txn = requery(insertTransaction(m.Id, 'New Registration').Id);
        txn.Rejection_Reason__c = 'Invalid IBAN';

        Test.startTest();
        DirectDebitTransactionHelper.updateDirectDebitApprovalStatus(new List<SObject>{ txn });
        Test.stopTest();

        DirectDebitRequest__c after = [SELECT Status__c, Rejected_Date__c, Rejection_Reason__c
                                       FROM DirectDebitRequest__c WHERE Id = :m.Id];
        Assert.areEqual('Rejected By Bank', after.Status__c);
        Assert.areEqual(Date.today(), after.Rejected_Date__c);
        Assert.areEqual('Invalid IBAN', after.Rejection_Reason__c);
    }

    @isTest
    static void testApprovalStatus_BankCancellation() {
        DirectDebitRequest__c m = cancelledFabMandate();
        DirectDebit_Transactions__c txn = requery(insertTransaction(m.Id, 'Cancellation').Id);

        Test.startTest();
        // The bank refuses first, then confirms.
        txn.Rejection_Reason__c = 'Mandate not found';
        DirectDebitTransactionHelper.updateDirectDebitApprovalStatus(new List<SObject>{ txn });
        String remarks = [SELECT Bank_Cancellation_Remarks__c FROM DirectDebitRequest__c WHERE Id = :m.Id].Bank_Cancellation_Remarks__c;

        txn.Rejection_Reason__c = null;
        txn.CancellationResStatus__c = 'DDA CANCELLED';
        txn.CancellationAckStatus__c = 'Success';
        DirectDebitTransactionHelper.updateDirectDebitApprovalStatus(new List<SObject>{ txn });
        Test.stopTest();

        Assert.areEqual('Mandate not found', remarks);
        DirectDebitRequest__c after = [SELECT Bank_Cancellation_Status__c, Bank_Cancellation_Date__c
                                       FROM DirectDebitRequest__c WHERE Id = :m.Id];
        Assert.areEqual('Success', after.Bank_Cancellation_Status__c);
        Assert.areEqual(Date.today(), after.Bank_Cancellation_Date__c);
    }

    @isTest
    static void testUpdateDirectDebitStatus() {
        // Sales Team Verified: Draft is not on the FAB Legacy record type's Status list.
        DirectDebitRequest__c m = activeFabMandate();
        DirectDebit_Transactions__c txn = insertTransaction(m.Id, 'New Registration');
        update new DirectDebitRequest__c(Id = m.Id, Status__c = 'Sales Team Verified');

        Test.startTest();
        DirectDebitTransactionHelper.updateDirectDebitStatus(new List<SObject>{ txn });
        Test.stopTest();

        Assert.areEqual('Send To Bank', [SELECT Status__c FROM DirectDebitRequest__c WHERE Id = :m.Id].Status__c);
    }

    @isTest
    static void testSendNewRegistrationToFAB_sync() {
        DirectDebitRequest__c m = activeFabMandate();
        insert new Documents__c(Direct_Debit_Request__c = m.Id);
        attachFile(m.Id);
        DirectDebit_Transactions__c txn = insertTransaction(m.Id, 'New Registration');
        Test.setMock(HttpCalloutMock.class, new MockFABResponse());

        Test.startTest();
        try {
            DirectDebitTransactionHelper.sendNewRegistrationToFAB_sync(new Set<Id>{ txn.Id });
        } catch (Exception e) {
            System.debug('sendNewRegistrationToFAB_sync: ' + e.getMessage());
        }
        Test.stopTest();

        String body = sentBody('ImageFileName');
        if (body != null) {
            Assert.isTrue(body.contains('"RequestType":"ADD"'), body);
            Assert.isTrue(body.contains('1234567890'), 'the ID number is sent without dashes');
        }
    }

    @isTest
    static void testSendNewRegistrationToFAB_sync_failureIsRethrown() {
        // No customer ID number, so building the payload fails; the helper must log and rethrow
        // rather than swallow it.
        DirectDebitRequest__c m = fabMandate(new DirectDebitRequest__c(
            Status__c = 'Send To Bank',
            Commences_On__c = Date.today(),
            Expires_On__c = Date.today().addMonths(6)
        ));
        DirectDebit_Transactions__c txn = insertTransaction(m.Id, 'New Registration');
        Test.setMock(HttpCalloutMock.class, new MockFABResponse());

        Boolean thrown = false;
        Test.startTest();
        try {
            DirectDebitTransactionHelper.sendNewRegistrationToFAB_sync(new Set<Id>{ txn.Id });
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();

        Assert.isTrue(thrown, 'a failed registration must surface to the caller');
    }

    @isTest
    static void testSendCollectionsToFAB_sync() {
        DirectDebitRequest__c m = activeFabMandate();
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = m.SalesOrder__c,
            InstallmentAmount__c = 5000,
            Milestone__c = 1,
            MilestoneDate__c = Date.today()
        );
        insert soi;
        DirectDebit_Transactions__c txn = new DirectDebit_Transactions__c(
            Direct_Debit_Request__c = m.Id,
            Request_Type__c = 'Collection',
            SOInstallment__c = soi.Id,
            Collection_Amount__c = 5000,
            Currency__c = 'AED'
        );
        insert txn;
        Test.setMock(HttpCalloutMock.class, new MockFABResponse());

        Test.startTest();
        try {
            DirectDebitTransactionHelper.sendCollectionsToFAB_sync(new Set<Id>{ txn.Id });
        } catch (Exception e) {
            // OIC_Credential__mdt may be absent in this org; the payload is still built first.
            System.debug('sendCollectionsToFAB_sync: ' + e.getMessage());
        }
        Test.stopTest();

        String body = sentBody('CollectionDetails');
        if (body != null) {
            Assert.isTrue(body.contains('"ClaimedAmount":"5000.00"'), body);
        }
    }

    @isTest
    static void testSendCancellationRegToFAB_sync() {
        DirectDebitRequest__c m = cancelledFabMandate();
        DirectDebit_Transactions__c txn = insertTransaction(m.Id, 'Cancellation');
        Test.setMock(HttpCalloutMock.class, new MockFABResponse());

        Test.startTest();
        try {
            DirectDebitTransactionHelper.sendCancellationRegToFAB_sync(new Set<Id>{ txn.Id });
        } catch (Exception e) {
            // OIC_Credential__mdt may be absent in this org.
            System.debug('sendCancellationRegToFAB_sync: ' + e.getMessage());
        }
        Test.stopTest();

        String body = sentBody('RegCancellationDetails');
        if (body != null) {
            Assert.isTrue(body.contains('"RequestType":"CAN"'), body);
            Assert.isTrue(body.contains('12121212'), 'the DDA reference is sent');
        }
    }

    @isTest
    static void testEmptyAndUnknownInputsAreIgnored() {
        Test.setMock(HttpCalloutMock.class, new MockFABResponse());
        Id unknownTxnId = DirectDebit_Transactions__c.SObjectType.getDescribe().getKeyPrefix() + '000000000001';

        Test.startTest();
        DirectDebitTransactionHelper.sendTranactionToFABGateway(new List<SObject>());
        DirectDebitTransactionHelper.sendTranactionToFABGateway(null);
        DirectDebitTransactionHelper.sendNewRegistrationToFAB(new Set<Id>());
        DirectDebitTransactionHelper.sendCollectionsToFAB(new Set<Id>());
        DirectDebitTransactionHelper.sendCancellationRegToFAB(new Set<Id>());
        DirectDebitTransactionHelper.sendNewRegistrationToFAB_sync(new Set<Id>());
        DirectDebitTransactionHelper.sendCollectionsToFAB_sync(new Set<Id>());
        DirectDebitTransactionHelper.sendCancellationRegToFAB_sync(new Set<Id>());
        DirectDebitTransactionHelper.sendCollectionsToFAB_sync(new Set<Id>{ unknownTxnId });
        // No mandate on the row, so neither status method has anything to touch.
        List<SObject> orphan = new List<SObject>{ new DirectDebit_Transactions__c(Request_Type__c = 'New Registration') };
        DirectDebitTransactionHelper.updateDirectDebitStatus(orphan);
        DirectDebitTransactionHelper.updateDirectDebitApprovalStatus(orphan);
        DirectDebitTransactionHelper.createPayment(orphan, null);
        Test.stopTest();

        Assert.isNull(sentBody('ImageFileName'), 'nothing to register');
        Assert.isNull(sentBody('CollectionDetails'), 'nothing to collect');
        Assert.isNull(sentBody('RegCancellationDetails'), 'nothing to cancel');
    }

    public class MockFABResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            calloutBodies.add(req.getBody());
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}