/**********************************************************************************************
 * Name           : UAEDDS_RepresentmentInvocableTest
 * Description     : Covers the Flow entry point for re-presenting a bounced payment. The case that
 *                   carries the weight is the split between inline and queued: representment is a
 *                   callout followed by DML, so exactly one request on a transaction that has done
 *                   no DML can answer the flow directly, and everything else has to be handed to
 *                   the queueable chain. A flow that got that wrong would fault on a CalloutException
 *                   rather than show the caller what the bank said.
 * Usage           : Test class for UAEDDS_RepresentmentInvocable.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Karunakar         20 Sep 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class UAEDDS_RepresentmentInvocableTest {

    /** The bank's answer to paymentRepresentment, as captured. */
    private static final String REPRESENTED =
        '{ "paymentId": 48958, "message": "Updated Successfully", "status": null }';

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
            FirstName = 'Represent',
            LastName = 'Tester',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'represent.tester@example.com.invalid',
            BillingCity = 'Abu Dhabi'
        );
        insert person;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'UAEDDS Represent Escrow');
        insert escrow;
        Phase__c phase = new Phase__c(Name = 'UAEDDS Represent Phase', EscrowAccount__c = escrow.Id);
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'UAEDDS Represent Unit', Phase__c = phase.Id, PlotNo__c = '11',
            Number_of_bedrooms__c = '2', UnitClassification__c = 'Apartment'
        );
        insert unit;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, TotalAmount__c = 100000);
        insert so;

        DirectDebitRequest__c mandate = new DirectDebitRequest__c(
            Account__c = person.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Approved By Bank',
            Bank_Status_Code__c = 'ACCP',
            DDA_Id__c = '80326',
            Customer_ID_Number__c = '784-1990-1234567-1',
            Customer_Id_Type__c = 'UAE Emirates Identity Card',
            CustomerAccountName__c = 'Represent Tester',
            Customer_Bank_Account_Name__c = 'Represent Tester',
            Customer_Bank_Name__c = 'First Abu Dhabi Bank',
            Customer_Bank_Account_Type__c = 'Current',
            Customer_IBAN_Number__c = 'AE070331234567890123456',
            Customer_Mobile__c = '+971561234567',
            Customer_City__c = 'Abu Dhabi',
            Commences_On__c = Date.today().addDays(-30),
            Expires_On__c = Date.today().addMonths(24),
            Minimum_Amount__c = 10,
            Maximum_Amount__c = 100000
        );
        insert mandate;
        // OIC__c is stamped before insert from the sales order's escrow account, and this sales
        // order has no virtual account to reach one through, so it is written afterwards.
        update new DirectDebitRequest__c(Id = mandate.Id, OIC__c = '550000356');

        insert new List<DirectDebit_Transactions__c>{
            payment(mandate.Id, '48958', 'Failure', 0),
            payment(mandate.Id, '48959', 'Failure', 1),
            // Settled, so representment is refused rather than sent.
            payment(mandate.Id, '48960', 'Success', 0)
        };
    }

    private static DirectDebit_Transactions__c payment(
        Id mandateId, String paymentId, String status, Integer used
    ) {
        return new DirectDebit_Transactions__c(
            Direct_Debit_Request__c = mandateId,
            Request_Type__c = 'UAEDDS Collection',
            Transaction_Status__c = status,
            UAEDDS_Payment_Id__c = paymentId,
            Representment_Count__c = used,
            Due_Date__c = Date.today().addDays(-1)
        );
    }

    /** SOQL, never DML - the inline path is chosen on Limits.getDmlStatements() being zero. */
    private static Id paymentId(String uaeddsPaymentId) {
        return [
            SELECT Id FROM DirectDebit_Transactions__c
            WHERE UAEDDS_Payment_Id__c = :uaeddsPaymentId LIMIT 1
        ].Id;
    }

    private static UAEDDS_RepresentmentInvocable.Request request(Id transactionId) {
        UAEDDS_RepresentmentInvocable.Request r = new UAEDDS_RepresentmentInvocable.Request();
        r.transactionId = transactionId;
        return r;
    }

    // ------------------------------------------------------------ inline

    /**
     * One request on a transaction that has done no DML is the only case that can answer the flow
     * with the bank's own answer, because a callout cannot follow DML. The screen flow shows this
     * message to whoever pressed the button.
     */
    @IsTest
    static void aSingleRequestAnswersTheFlowDirectly() {
        Id transactionId = paymentId('48958');
        Test.setMock(HttpCalloutMock.class, new Mock(REPRESENTED));

        Test.startTest();
        List<UAEDDS_RepresentmentInvocable.Response> responses =
            UAEDDS_RepresentmentInvocable.represent(
                new List<UAEDDS_RepresentmentInvocable.Request>{ request(transactionId) }
            );
        Test.stopTest();

        Assert.areEqual(1, responses.size(), 'one request, one response');
        UAEDDS_RepresentmentInvocable.Response res = responses[0];
        Assert.areEqual(transactionId, res.transactionId);
        Assert.isTrue(res.success, res.message);
        Assert.isFalse(res.queued, 'nothing was handed to a queueable');
        Assert.isTrue(res.message.containsIgnoreCase('lifecycle'), res.message);

        DirectDebit_Transactions__c after = [
            SELECT Transaction_Status__c, Representment_Count__c, Represented_Date__c
            FROM DirectDebit_Transactions__c WHERE Id = :transactionId
        ];
        Assert.areEqual(1, after.Representment_Count__c, 'the attempt was counted');
        Assert.areEqual('Initiated', after.Transaction_Status__c, 'back in the lifecycle');
        Assert.isNotNull(after.Represented_Date__c);
    }

    /**
     * A refusal is returned rather than thrown. Representment is refused for ordinary reasons - the
     * payment settled, the attempts are used up - and a flow's job is to say so, not to fault.
     */
    @IsTest
    static void aRefusalComesBackAsAMessageRatherThanAFault() {
        Id settledId = paymentId('48960');

        Test.startTest();
        List<UAEDDS_RepresentmentInvocable.Response> responses =
            UAEDDS_RepresentmentInvocable.represent(
                new List<UAEDDS_RepresentmentInvocable.Request>{ request(settledId) }
            );
        Test.stopTest();

        UAEDDS_RepresentmentInvocable.Response res = responses[0];
        Assert.isFalse(res.success, 'a settled payment cannot be re-presented');
        Assert.isFalse(res.queued);
        Assert.isTrue(
            res.message.containsIgnoreCase('Only a failed payment'),
            'the service\'s own words reach the flow: ' + res.message
        );
    }

    /**
     * The bank refusing inside an HTTP 200. ok is false, so the flow is told the call was not
     * accepted rather than being congratulated on a rejection.
     */
    @IsTest
    static void aBankRefusalIsReportedAsAFailure() {
        Id transactionId = paymentId('48958');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentId": 48958, "errors": "Payment cannot be represented" }'
        ));

        Test.startTest();
        List<UAEDDS_RepresentmentInvocable.Response> responses =
            UAEDDS_RepresentmentInvocable.represent(
                new List<UAEDDS_RepresentmentInvocable.Request>{ request(transactionId) }
            );
        Test.stopTest();

        Assert.isFalse(responses[0].success, 'the vendor refused it, whatever the HTTP status said');
        Assert.isNotNull(responses[0].message);
    }

    // ------------------------------------------------------------ guards

    @IsTest
    static void noRequestsIsNoWork() {
        Test.startTest();
        Assert.areEqual(
            0,
            UAEDDS_RepresentmentInvocable.represent(
                new List<UAEDDS_RepresentmentInvocable.Request>()
            ).size(),
            'an empty invocation answers with nothing rather than throwing'
        );
        Assert.areEqual(0, UAEDDS_RepresentmentInvocable.represent(null).size(), 'and so does null');
        Test.stopTest();
    }

    /** A flow variable that resolved to nothing. Named rather than silently skipped. */
    @IsTest
    static void aRequestWithNoTransactionSaysSo() {
        Test.startTest();
        List<UAEDDS_RepresentmentInvocable.Response> responses =
            UAEDDS_RepresentmentInvocable.represent(
                new List<UAEDDS_RepresentmentInvocable.Request>{ request(null) }
            );
        Test.stopTest();

        Assert.areEqual(1, responses.size());
        Assert.isFalse(responses[0].success);
        Assert.isFalse(responses[0].queued);
        Assert.isTrue(
            responses[0].message.containsIgnoreCase('nothing to re-present'), responses[0].message
        );
    }

    // ------------------------------------------------------------ queued

    /**
     * Two requests cannot both run inline: representment is a callout plus an update, and the second
     * callout would follow the first one's DML. Both are queued, and the chain walks them one
     * transaction at a time - a queueable cannot chain inside a test, so the first is what runs here.
     */
    @IsTest
    static void severalRequestsAreQueuedRatherThanFaulting() {
        Id first = paymentId('48958');
        Id second = paymentId('48959');
        Test.setMock(HttpCalloutMock.class, new Mock(REPRESENTED));

        Test.startTest();
        List<UAEDDS_RepresentmentInvocable.Response> responses =
            UAEDDS_RepresentmentInvocable.represent(
                new List<UAEDDS_RepresentmentInvocable.Request>{
                    request(first), request(second)
                }
            );
        Test.stopTest();

        Assert.areEqual(2, responses.size());
        for (UAEDDS_RepresentmentInvocable.Response res : responses) {
            Assert.isTrue(res.queued, 'handed to the queueable rather than answered here');
            Assert.isTrue(res.success, 'a queued request reports true: nothing has been refused yet');
            Assert.isTrue(res.message.containsIgnoreCase('Queued'), res.message);
        }

        // The job ran at stopTest and re-presented the first of the two.
        Assert.areEqual(
            1,
            [SELECT Representment_Count__c FROM DirectDebit_Transactions__c WHERE Id = :first]
                .Representment_Count__c,
            'the queueable did the work the flow could not do inline'
        );
    }

    /**
     * A request that arrives after the caller has already saved something. inline is false because
     * DML has been done, so this goes async rather than dying on "uncommitted work pending".
     */
    @IsTest
    static void aRecordTriggeredFlowThatAlreadySavedIsQueuedToo() {
        Id transactionId = paymentId('48958');
        Test.setMock(HttpCalloutMock.class, new Mock(REPRESENTED));

        Test.startTest();
        // Whatever the flow saved before calling the action. One statement is enough.
        update new DirectDebit_Transactions__c(Id = transactionId, Remarks__c = 'flow saved first');
        List<UAEDDS_RepresentmentInvocable.Response> responses =
            UAEDDS_RepresentmentInvocable.represent(
                new List<UAEDDS_RepresentmentInvocable.Request>{ request(transactionId) }
            );
        Test.stopTest();

        Assert.isTrue(responses[0].queued, 'a callout cannot follow the flow\'s own DML');
        Assert.areEqual(
            1,
            [SELECT Representment_Count__c FROM DirectDebit_Transactions__c WHERE Id = :transactionId]
                .Representment_Count__c,
            'and the work still happened, one transaction later'
        );
    }

    /**
     * Nobody is watching a queueable, so a refusal inside one has to reach Logger__c rather than
     * only the job owner's inbox. The chain carries on with the payments behind it.
     */
    @IsTest
    static void aRefusalInsideTheQueueableIsLogged() {
        Id settledId = paymentId('48960');
        Id failedId = paymentId('48958');
        Test.setMock(HttpCalloutMock.class, new Mock(REPRESENTED));

        Test.startTest();
        UAEDDS_RepresentmentInvocable.represent(
            new List<UAEDDS_RepresentmentInvocable.Request>{
                // Settled, so the first link refuses and the failure is logged.
                request(settledId), request(failedId)
            }
        );
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Logger__c
             WHERE ClassName__c = 'UAEDDS_RepresentmentInvocable'
               AND ExecutingProcessName__c = 'UAEDDS_Representment'],
            'the refusal is written where the rest of the UAEDDS trail is'
        );
    }
}