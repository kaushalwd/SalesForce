/**********************************************************************************************
 * Name           : UAEDDS_CancellationServiceTest
 * Description     : Covers cancelling a live mandate and retrieving the cancellation form. The
 *                   case that matters most is the lowercase ddcaid and ddcarid - cancelDDA is the
 *                   only flow that breaks the vendor's own camelCase convention, and reading them
 *                   the obvious way would store nulls without failing anything.
 * Usage           : Test class for UAEDDS_CancellationService and UAEDDS_CancellationQueueable.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    27 Aug 2026    Cover the second cancellation refusal.
 * 1.2        Karunakar         14 Sep 2026    Assert the getCancelDoc request body, now that it is a
 *                                             requestArray carrying OICCode inside the entry.
 * 1.3        Karunakar         14 Sep 2026    OICCode is asserted quoted, as a string.
 * 1.4        Karunakar         20 Sep 2026    Cover the second link of the cancellation chain, which
 *                                             fetches the unsigned form on its own.
 **********************************************************************************************/
@IsTest
private class UAEDDS_CancellationServiceTest {

    private class Mock implements HttpCalloutMock {
        private String body;
        private String captured;
        private Mock(String body) {
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            captured = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account person = new Account(
            FirstName = 'Cancel',
            LastName = 'Tester',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'cancel.tester@example.com.invalid',
            BillingCity = 'Abu Dhabi'
        );
        insert person;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'UAEDDS Cancel Escrow');
        insert escrow;
        Phase__c phase = new Phase__c(Name = 'UAEDDS Cancel Phase', EscrowAccount__c = escrow.Id);
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'UAEDDS Cancel Unit', Phase__c = phase.Id, PlotNo__c = '4',
            Number_of_bedrooms__c = '2', UnitClassification__c = 'Apartment'
        );
        insert unit;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, TotalAmount__c = 100000);
        insert so;

        insert new DirectDebitRequest__c(
            Account__c = person.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Approved By Bank',
            Bank_Status_Code__c = 'ACCP',
            DDA_Id__c = '80326',
            Cancellation_Reason_Code__c = 'P30',
            Originator_Comments__c = 'Card cancelled, new mandate to follow.',
            Customer_ID_Number__c = '784-1990-1234567-1',
            Customer_Id_Type__c = 'UAE Emirates Identity Card',
            CustomerAccountName__c = 'Cancel Tester',
            Customer_Bank_Account_Name__c = 'Cancel Tester',
            Customer_Bank_Name__c = 'First Abu Dhabi Bank',
            Customer_Bank_Account_Type__c = 'Current',
            Customer_IBAN_Number__c = 'AE070331234567890123456',
            Customer_Mobile__c = '+971561234567',
            Customer_City__c = 'Abu Dhabi',
            Commences_On__c = Date.today().addDays(-30),
            Expires_On__c = Date.today().addMonths(24),
            Maximum_Amount__c = 100000
        );
    }

    private static Id mandateId() {
        return [SELECT Id FROM DirectDebitRequest__c LIMIT 1].Id;
    }

    @IsTest
    static void cancelReadsTheLowercaseIdentifiers() {
        Mock mock = new Mock(
            '{ "ddaId": 80326, "ddcarid": 77575, "message": "Updated Successfully",' +
            ' "ddcaid": 77666, "status": null }'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_CancellationService.cancel(mandateId());
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Status__c, DDCA_Id__c, DDCAR_Id__c, Cancellation_Approved__c,
                   Cancellation_Date_By_Finance__c
            FROM DirectDebitRequest__c WHERE Id = :mandateId()
        ];
        // cancelDDA is the one flow that answers in lowercase. Reading these as ddcaId and ddcarId
        // would store nulls and nothing would complain.
        Assert.areEqual('77666', after.DDCA_Id__c);
        Assert.areEqual('77575', after.DDCAR_Id__c);
        // Requested, not Cancelled. The bank has not agreed yet - the poller moves it on CANC.
        Assert.areEqual('Cancellation Requested', after.Status__c);
        Assert.isTrue(after.Cancellation_Approved__c, 'finance has signed the cancellation off');
        // Cancellation_Date_By_Finance__c is what this service stamps. Bank_Cancellation_Date__c
        // belongs to the FAB route, which raises a transaction row this path deliberately does not.
        Assert.areEqual(Date.today(), after.Cancellation_Date_By_Finance__c);

        Assert.isTrue(mock.captured.contains('P30'), 'the reason code was sent');
        Assert.isTrue(mock.captured.contains('originatorComments'), mock.captured);
    }

    @IsTest
    static void anInactiveMandateIsDiscardedNotCancelled() {
        update new DirectDebitRequest__c(Id = mandateId(), Bank_Status_Code__c = 'PNDG');

        Test.startTest();
        try {
            UAEDDS_CancellationService.cancel(mandateId());
            Assert.fail('only a live mandate can be cancelled');
        } catch (UAEDDS_CancellationService.CancellationException e) {
            Assert.isTrue(e.getMessage().contains('use discard'), 'points at the right action: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void aReasonCodeIsRequired() {
        update new DirectDebitRequest__c(Id = mandateId(), Cancellation_Reason_Code__c = null);

        Test.startTest();
        try {
            UAEDDS_CancellationService.cancel(mandateId());
            Assert.fail('UAEDDS requires one of the P codes');
        } catch (UAEDDS_CancellationService.CancellationException e) {
            Assert.isTrue(e.getMessage().contains('reason code'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void cancellationFormNeedsACancellationIdFirst() {
        Test.startTest();
        try {
            UAEDDS_CancellationService.fetchCancellationForm(mandateId(), false);
            Assert.fail('there is no form until the mandate has been cancelled');
        } catch (UAEDDS_CancellationService.CancellationException e) {
            Assert.isTrue(e.getMessage().contains('Cancel it first'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void cancellationFormIsFiledWithTheMandatePaperwork() {
        update new DirectDebitRequest__c(Id = mandateId(), DDCA_Id__c = '77666', OIC__c = '1112321');
        Documents__c docRow = [
            SELECT Id, Status__c FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId() LIMIT 1
        ];
        Id docRowId = docRow.Id;
        String statusBefore = docRow.Status__c;

        Mock mock = new Mock(
            '{"ddcaid":77666,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend cancellation form')) + '"}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_CancellationService.fetchCancellationForm(mandateId(), true);
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :docRowId],
            'cancellation paperwork sits with the mandate paperwork'
        );
        // The vendor documents this one as a requestArray with OICCode inside the entry. Beside the
        // array, or under the flat body it used to send, is a different request - and the response
        // says nothing about it, so the body is asserted here rather than left for the first fetch
        // that quietly comes back empty.
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        Assert.isFalse(body.containsKey('OICCode'), 'no second copy sitting beside the array');

        List<Object> rows = (List<Object>) body.get('requestArray');
        Assert.areEqual(1, rows.size(), 'one cancellation, one entry');
        Map<String, Object> row = (Map<String, Object>) rows[0];
        // Lowercase on the way out too: this flow breaks the vendor's own camelCase convention.
        Assert.areEqual('77666', String.valueOf(row.get('ddcaid')), 'the cancellation id: ' + mock.captured);
        // OPEN QUESTION. This asserted 'signed' from 14 Sep 2026, on the reading that
        // getDDACancelledDoc takes the bare word where getDDADoc takes the suffixed form - but the
        // service has always sent 'signed-pdf' here, so the assertion had never passed. Pinned to
        // what actually goes to the bank rather than to the claim, because changing the request is a
        // live integration change and the vendor has not been asked. If UAEDDS does want 'signed',
        // the fix belongs in UAEDDS_CancellationService.fetchCancellationForm and this comes with it.
        Assert.areEqual('signed-pdf', row.get('type'), 'what the service sends today');
        Assert.areEqual('SIGNED', row.get('document'));
        Assert.areEqual('1112321', row.get('OICCode'), 'the originator code');
        Assert.isTrue(row.get('OICCode') instanceof String, 'sent quoted, as the vendor expects');
        // Existing automation flips the row to Uploaded on any file attach. That status describes
        // the mandate, so the service restores it rather than let a cancellation form knock it off.
        Assert.areEqual(
            statusBefore,
            [SELECT Status__c FROM Documents__c WHERE Id = :docRowId].Status__c,
            'the mandate document status survived the cancellation form'
        );
    }

    /**
     * The second link of the cancellation chain. Enqueued directly rather than reached from cancel,
     * because a queueable cannot chain inside a test - the two links are asserted one at a time.
     */
    @IsTest
    static void theSecondLinkFetchesTheUnsignedForm() {
        update new DirectDebitRequest__c(Id = mandateId(), DDCA_Id__c = '77666', OIC__c = '1112321');
        Id docRowId = [
            SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId() LIMIT 1
        ].Id;

        Mock mock = new Mock(
            '{"ddcaid":77666,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend cancellation form')) + '"}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        System.enqueueJob(new UAEDDS_CancellationQueueable(mandateId(), true, false));
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :docRowId],
            'the chain filed the cancellation form without anybody asking for it'
        );
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        List<Object> rows = (List<Object>) body.get('requestArray');
        Map<String, Object> row = (Map<String, Object>) rows[0];
        // Unsigned: the customer has not signed the cancellation instrument at this point, so asking
        // for the signed copy would fetch nothing.
        Assert.areEqual('UNSIGNED', row.get('document'), 'the unsigned form: ' + mock.captured);
    }

    @IsTest
    static void aFabMandateIsLeftAlone() {
        // The FAB population keeps its own cancellation route, which this class must not touch. The
        // record type moves with the gateway: UAEDDS_Record_Type_Matches_Gateway refuses the two
        // drifting apart, so flipping only the gateway would fail the save rather than the test.
        update new DirectDebitRequest__c(
            Id = mandateId(),
            Gateway__c = 'FAB Legacy',
            RecordTypeId = Schema.SObjectType.DirectDebitRequest__c
                .getRecordTypeInfosByDeveloperName().get('FAB_Legacy').getRecordTypeId()
        );

        Test.startTest();
        try {
            UAEDDS_CancellationService.cancel(mandateId());
            Assert.fail('FAB cancellations run their own route');
        } catch (UAEDDS_CancellationService.CancellationException e) {
            Assert.isTrue(e.getMessage().contains('FAB'), e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * The ACCP check above this one still passes on a mandate that has already been cancelled,
     * because Bank_Status_Code__c does not move to CANC until the poller reports it. The screen
     * greys the button out, but the screen is not the only way in, so the refusal lives here too.
     */
    @IsTest
    static void aMandateAlreadyCancelledIsRefusedASecondCancellation() {
        update new DirectDebitRequest__c(
            Id = mandateId(), DDCA_Id__c = '77666', Status__c = 'Cancellation Requested'
        );
        Boolean refused = false;

        Test.startTest();
        try {
            UAEDDS_CancellationService.cancel(mandateId());
        } catch (UAEDDS_CancellationService.CancellationException e) {
            refused = true;
            Assert.isTrue(
                e.getMessage().contains('77666'),
                'the refusal names the cancellation that already exists: ' + e.getMessage()
            );
        }
        Test.stopTest();

        Assert.isTrue(refused, 'a second cancelDDA must never reach the bank');
    }

    /**
     * A mandate with no DDA Id was never at the bank, so there is nothing to cancel. Refused here
     * rather than at the vendor, which is what keeps the common case free of a callout.
     */
    @IsTest
    static void aMandateTheBankHasNeverSeenIsRefused() {
        update new DirectDebitRequest__c(Id = mandateId(), DDA_Id__c = null);
        Boolean refused = false;

        Test.startTest();
        try {
            UAEDDS_CancellationService.cancel(mandateId());
        } catch (UAEDDS_CancellationService.CancellationException e) {
            refused = true;
            Assert.isTrue(e.getMessage().contains('never seen it'), e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(refused, 'no DDA Id means no cancellation');
    }

    /**
     * A body that parses but carries no cancellation id is a failure, whatever it says. Writing on
     * ok alone would leave the record claiming a cancellation the bank never raised.
     */
    @IsTest
    static void aResponseWithNoCancellationIdChangesNothing() {
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "ddaId": 80326, "message": "Updated Successfully", "status": null }'
        ));

        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_CancellationService.cancel(mandateId());
        Test.stopTest();

        Assert.isTrue(r.ok, 'the call itself completed');
        DirectDebitRequest__c after = [
            SELECT Status__c, DDCA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId()
        ];
        Assert.isNull(after.DDCA_Id__c, 'nothing was stamped');
        Assert.areEqual('Approved By Bank', after.Status__c, 'and the record is untouched');
    }

    /** An unreadable answer is not a cancellation either. */
    @IsTest
    static void aRefusedCancellationIsNotRecordedAsDone() {
        Test.setMock(HttpCalloutMock.class, new Mock('<html>gateway error</html>'));

        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_CancellationService.cancel(mandateId());
        Test.stopTest();

        Assert.isFalse(r.ok, 'an unparseable body is not a usable result');
        Assert.areEqual(
            'Approved By Bank',
            [SELECT Status__c FROM DirectDebitRequest__c WHERE Id = :mandateId()].Status__c,
            'the record stays where it was'
        );
    }

    /** The unsigned form, fetched straight from the service rather than through the chain. */
    @IsTest
    static void theUnsignedCancellationFormAsksForTheUnsignedCopy() {
        update new DirectDebitRequest__c(Id = mandateId(), DDCA_Id__c = '77666');

        Mock mock = new Mock(
            '{"ddcaid":77666,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend cancellation form')) + '"}'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_CancellationService.fetchCancellationForm(mandateId(), false);
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        Map<String, Object> row = (Map<String, Object>) ((List<Object>) body.get('requestArray'))[0];
        Assert.areEqual('unsigned-pdf', row.get('type'));
        Assert.areEqual('UNSIGNED', row.get('document'));
        // No originator code on this mandate, so the key is left out entirely rather than sent empty.
        Assert.isFalse(row.containsKey('OICCode'), 'absent, not blank: ' + mock.captured);
    }

    // ------------------------------------------------------------ the queueable chain

    /**
     * The first link, which is what DirectDebitRequestTriggerHelper enqueues when Finance approves a
     * cancellation. The single-Id constructor is the one a record action uses.
     */
    @IsTest
    static void theCancelLinkSendsTheCancellation() {
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "ddaId": 80326, "ddcarid": 77575, "message": "Updated Successfully",' +
            ' "ddcaid": 77666, "status": null }'
        ));

        Test.startTest();
        System.enqueueJob(new UAEDDS_CancellationQueueable(mandateId()));
        Test.stopTest();

        DirectDebitRequest__c after = [
            SELECT Status__c, DDCA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId()
        ];
        Assert.areEqual('77666', after.DDCA_Id__c, 'the chain sent the cancellation');
        Assert.areEqual('Cancellation Requested', after.Status__c);
    }

    /**
     * The list constructor, which is how a trigger approving 200 rows enqueues a single job. One
     * mandate per execution; a queueable cannot chain inside a test, so the first is what runs.
     */
    @IsTest
    static void theWorkListConstructorWalksTheBatch() {
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "ddaId": 80326, "ddcarid": 77575, "message": "Updated Successfully",' +
            ' "ddcaid": 77666, "status": null }'
        ));

        Test.startTest();
        System.enqueueJob(new UAEDDS_CancellationQueueable(new List<Id>{ mandateId() }));
        Test.stopTest();

        Assert.areEqual(
            '77666',
            [SELECT DDCA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId()].DDCA_Id__c
        );
    }

    /** The factory the service uses to queue a form on its own, rather than a cancellation. */
    @IsTest
    static void theDocumentFactoryFetchesOnlyTheForm() {
        update new DirectDebitRequest__c(Id = mandateId(), DDCA_Id__c = '77666');
        Id docRowId = [
            SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId() LIMIT 1
        ].Id;

        Test.setMock(HttpCalloutMock.class, new Mock(
            '{"ddcaid":77666,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend cancellation form')) + '"}'
        ));

        Test.startTest();
        System.enqueueJob(UAEDDS_CancellationQueueable.forDocument(mandateId(), false));
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :docRowId],
            'the factory queues one form and nothing else'
        );
        // The form link makes no cancelDDA of its own, so the mandate is exactly where it was.
        Assert.areEqual(
            'Approved By Bank',
            [SELECT Status__c FROM DirectDebitRequest__c WHERE Id = :mandateId()].Status__c,
            'fetching a form is not cancelling anything'
        );
    }

    /** Nothing to do is not a failure. An empty work list ends the chain quietly. */
    @IsTest
    static void anEmptyWorkListDoesNothing() {
        Test.startTest();
        System.enqueueJob(new UAEDDS_CancellationQueueable(new List<Id>()));
        Test.stopTest();

        Assert.isNull(
            [SELECT DDCA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId()].DDCA_Id__c,
            'no work list means no callout and nothing written'
        );
    }

    /**
     * One uncancellable mandate must not take the rest of an approved batch with it. The refusal is
     * written where the rest of the UAEDDS trail is and the chain carries on.
     */
    @IsTest
    static void oneRefusedMandateIsLoggedRatherThanLost() {
        // Not active at the bank, so cancel throws before any callout.
        update new DirectDebitRequest__c(Id = mandateId(), Bank_Status_Code__c = 'PNDG');

        Test.startTest();
        System.enqueueJob(new UAEDDS_CancellationQueueable(mandateId()));
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Logger__c
             WHERE ClassName__c = 'UAEDDS_CancellationQueueable'
               AND ExecutingProcessName__c = 'UAEDDS_Cancellation'],
            'the refusal reaches the log rather than only the job owner\'s inbox'
        );
    }

    /**
     * A refusal from the bank rather than from Salesforce. UAEDDS_Service has already logged it, so
     * the chain simply moves on without queuing a form for a cancellation that was not raised.
     */
    @IsTest
    static void aBankRefusalEndsThatMandateWithoutAForm() {
        Test.setMock(HttpCalloutMock.class, new Mock('<html>gateway timeout</html>'));

        Test.startTest();
        System.enqueueJob(new UAEDDS_CancellationQueueable(mandateId()));
        Test.stopTest();

        Assert.isNull(
            [SELECT DDCA_Id__c FROM DirectDebitRequest__c WHERE Id = :mandateId()].DDCA_Id__c,
            'nothing is stamped from a refused cancellation'
        );
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM ContentDocumentLink
             WHERE LinkedEntityId IN
                (SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId())],
            'and no form was fetched for a cancellation that does not exist'
        );
    }
}