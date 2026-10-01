/**********************************************************************************************
 * Name           : CheckoutPaymentPollerTest
 * Description     : Test coverage for CheckoutPaymentPoller (status polling batch/schedulable).
 * Usage           : Apex unit test.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.1        Prateek Bansal    10 Sep 2026    Held rows are only polled once their authorisation
 *                                             expiry passes, so cover both sides of that rule.
 * 1.0        Prateek Bansal    25 Jun 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class CheckoutPaymentPollerTest {

    private class PollMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"data":[{"id":"pay_poll1","status":"Captured","reference":"CKO-POLL",' +
                '"source":{"last4":"1234","scheme":"Visa","bin":"424242","card_type":"Credit",' +
                '"card_category":"Consumer","issuer":"CKO BANK","issuer_country":"GB",' +
                '"expiry_month":12,"expiry_year":2030}}],"total_count":1}');
            return res;
        }
    }

    // Hosted Payments Page rows resolve status via the session (/hosted-payments/{id}) then the
    // payment (/payments/{id}) - not the reference search - so this mock branches by path.
    private class HostedPollMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String ep = req.getEndpoint();
            if (ep.contains('/hosted-payments/')) {
                res.setBody('{"id":"hpp_x","status":"Payment Received","payment_id":"pay_hpp1","reference":"CKO-HPP"}');
            } else if (ep.contains('/payments/')) {
                res.setBody('{"id":"pay_hpp1","status":"Captured","reference":"CKO-HPP",' +
                    '"source":{"last4":"4242","scheme":"Visa"}}');
            } else {
                res.setBody('{"data":[]}');
            }
            return res;
        }
    }

    @IsTest
    static void hostedPaymentPollResolvesViaSession() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-HPP', Payment_Link_Id__c = 'hpp_x', Status__c = 'Link Created',
            Amount__c = 100, Currency_Code__c = 'AED'
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new HostedPollMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Payment_Id__c, Card_Last4__c, Error_Message__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals('Captured', after.Status__c, 'HPP session resolved to the captured payment');
        System.assertEquals('pay_hpp1', after.Payment_Id__c, 'Payment id resolved via the session');
        System.assertEquals('4242', after.Card_Last4__c, 'Card details captured from the payment');
        System.assertEquals(null, after.Error_Message__c, 'No error stamped on a successful poll');
    }

    @IsTest
    static void capturedRowMaterialisesInFinish() {
        Account acc = new Account(Name = 'Poller EOI Account', Phone = '+971500000000');
        insert acc;

        // The unidentified finance account is org data and invisible under @IsTest, so point the
        // shared receipt builder at this account or every receipt is skipped.
        EoiReceiptBuilder.accountIdOverride = acc.Id;
        Contact con = new Contact(AccountId = acc.Id, FirstName = 'Poll', LastName = 'Contact',
            Email = 'poll.contact@example.com', MobilePhone = '+971500000001');
        insert con;
        Opportunity opp = new Opportunity(Name = 'Poller EOI Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id);
        if (Opportunity.SObjectType.getDescribe().fields.getMap().containsKey('contactid')) {
            opp.put('ContactId', con.Id);
        }
        insert opp;

        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => opp.Id, 'eoiAmount' => 500, 'numberOfUnits' => 1,
            'paymentType' => 'Online', 'remarks' => 'poller finish test'
        });
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-HPP', Payment_Link_Id__c = 'hpp_x', Status__c = 'Link Created',
            Amount__c = 500, Currency_Code__c = 'AED', EOI_Creation_Payload__c = payload
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new HostedPollMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        // execute() captures the row; finish() enqueues CheckoutMaterializeQueueable (v1.1 -
        // finish must not materialise inline, the EOI cascade's @future is illegal in batch).
        // stopTest drains the chained queueable; runAllNow() proves idempotence on the healed row.
        CheckoutMaterializeQueueable.runAllNow(7);

        Checkout_Payment__c after = [
            SELECT Status__c, Expression_of_Interest__c, Receipt__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals('Captured', after.Status__c, 'Row captured in execute');
        System.assertNotEquals(null, after.Expression_of_Interest__c, 'EOI materialised by the queueable');
        System.assertNotEquals(null, after.Receipt__c, 'Receipt materialised by the queueable');
    }

    @IsTest
    static void batchUpdatesOpenRows() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-POLL', Status__c = 'Link Created',
            Amount__c = 100, Currency_Code__c = 'AED'
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new PollMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Payment_Id__c, Card_Last4__c, Card_Scheme__c, Card_BIN__c,
                   Issuer__c, Issuer_Country__c, Card_Expiry__c, Last_Polled__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals('Captured', after.Status__c, 'Checkout status mapped to row status');
        System.assertEquals('pay_poll1', after.Payment_Id__c, 'Payment id captured from poll');
        System.assertEquals('1234', after.Card_Last4__c, 'Card last4 captured');
        System.assertEquals('Visa', after.Card_Scheme__c, 'Card scheme captured');
        System.assertEquals('424242', after.Card_BIN__c, 'Card BIN captured');
        System.assertEquals('CKO BANK', after.Issuer__c, 'Issuer captured');
        System.assertEquals('12/2030', after.Card_Expiry__c, 'Card expiry captured');
        System.assertNotEquals(null, after.Last_Polled__c, 'Poll timestamp set');
    }

    @IsTest
    static void schedulableEntryRunsBatch() {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = 'CKO-POLL', Status__c = 'Authorized',
            Amount__c = 100, Currency_Code__c = 'AED'
        );
        insert cp;

        Test.setMock(HttpCalloutMock.class, new PollMock());
        Test.startTest();
        new CheckoutPaymentPoller().execute((SchedulableContext) null);
        Test.stopTest();

        Checkout_Payment__c after = [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id];
        System.assertEquals('Captured', after.Status__c, 'Schedulable entry triggers the batch');
        Integer scheduled = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'Checkout Poller%'];
        System.assert(scheduled >= 1, 'Schedulable entry self-schedules the next run');
    }

    @IsTest
    static void batchExpiresUnpaidLinksWithoutCallout() {
        Checkout_Payment__c expired = new Checkout_Payment__c(
            Reference__c = 'CKO-EXP', Status__c = 'Link Created',
            Amount__c = 100, Currency_Code__c = 'AED',
            Expires_On__c = System.now().addDays(-1)
        );
        Checkout_Payment__c live = new Checkout_Payment__c(
            Reference__c = 'CKO-POLL', Status__c = 'Link Created',
            Amount__c = 100, Currency_Code__c = 'AED',
            Expires_On__c = System.now().addDays(1)
        );
        insert new List<Checkout_Payment__c>{ expired, live };

        Test.setMock(HttpCalloutMock.class, new PollMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c afterExpired = [
            SELECT Status__c, Payment_Id__c FROM Checkout_Payment__c WHERE Id = :expired.Id
        ];
        System.assertEquals('Expired', afterExpired.Status__c, 'Past-expiry link flipped to Expired');
        System.assertEquals(null, afterExpired.Payment_Id__c, 'No callout made for the expired link');

        Checkout_Payment__c afterLive = [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :live.Id];
        System.assertEquals('Captured', afterLive.Status__c, 'Non-expired link still polled and updated');
    }

    @IsTest
    static void holdWithTimeLeftIsNotPolled() {
        // Capture and void are manual actions taken in Salesforce, so a hold that is nowhere near
        // expiry has nothing a callout could tell us. It should be left alone.
        Checkout_Payment__c hold = new Checkout_Payment__c(
            Reference__c = 'CKO-POLL', Status__c = 'Authorized',
            Amount__c = 100, Currency_Code__c = 'AED',
            Payment_Id__c = 'pay_held',
            Authorization_Expires_On__c = System.now().addDays(9)
        );
        insert hold;

        Test.setMock(HttpCalloutMock.class, new PollMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Payment_Id__c, Last_Polled__c FROM Checkout_Payment__c WHERE Id = :hold.Id
        ];
        System.assertEquals('Authorized', after.Status__c, 'A hold with time left is untouched');
        System.assertEquals('pay_held', after.Payment_Id__c, 'And keeps its own payment');
        System.assertEquals(null, after.Last_Polled__c,
            'No callout was spent on it - this is the whole point of the change');
    }

    @IsTest
    static void holdPastItsExpiryIsPolled() {
        // Expiry is the one thing a poll can still discover about a hold, so once the date passes we
        // do ask Checkout - rather than assuming, which would cancel the EOI on a stored date alone.
        // HostedPollMock, not PollMock: a row that already knows its payment id is read by
        // GET /payments/{id}, so the mock has to answer with a single payment rather than a
        // reference search result.
        Checkout_Payment__c lapsed = new Checkout_Payment__c(
            Reference__c = 'CKO-POLL', Status__c = 'Authorized',
            Amount__c = 100, Currency_Code__c = 'AED',
            Payment_Id__c = 'pay_lapsed',
            Authorization_Expires_On__c = System.now().addMinutes(-5)
        );
        insert lapsed;

        Test.setMock(HttpCalloutMock.class, new HostedPollMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Last_Polled__c FROM Checkout_Payment__c WHERE Id = :lapsed.Id
        ];
        System.assertEquals('Captured', after.Status__c, 'Checkout was asked and its answer applied');
        System.assertNotEquals(null, after.Last_Polled__c, 'Poll timestamp set');
    }

    // A retry on the same link is a new payment under the same reference, so the search answers
    // with an id the row has never seen.
    private class RetryMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"data":[{"id":"pay_retry","status":"Authorized","reference":"CKO-RETRY",' +
                '"source":{"last4":"4242","scheme":"Visa"}}],"total_count":2}');
            return res;
        }
    }

    @IsTest
    static void aDeclinedRowKeepsPollingWhileItsLinkIsOpen() {
        // The bug this exists for: a customer retries on the same link and succeeds, and nobody sees
        // it because the row stopped being polled at the first decline. Three live Production holds
        // sat unnoticed for up to 20 hours that way.
        Checkout_Payment__c declined = new Checkout_Payment__c(
            Reference__c = 'CKO-RETRY', Status__c = 'Declined',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Payment_Id__c = 'pay_dead', Error_Message__c = '20059 - Suspected Fraud',
            Expires_On__c = System.now().addHours(6)
        );
        insert declined;

        Test.setMock(HttpCalloutMock.class, new RetryMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Payment_Id__c FROM Checkout_Payment__c WHERE Id = :declined.Id
        ];
        System.assertEquals('Authorized', after.Status__c, 'The retry was found without anyone looking');
        System.assertEquals('pay_retry', after.Payment_Id__c, 'And the row now points at the live payment');
    }

    @IsTest
    static void aDeclinedRowIsDroppedOnceItsLinkHasClosed() {
        // No retry is possible on a closed link, so there is nothing left to discover.
        Checkout_Payment__c stale = new Checkout_Payment__c(
            Reference__c = 'CKO-RETRY', Status__c = 'Declined',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Payment_Id__c = 'pay_dead',
            Expires_On__c = System.now().addHours(-1)
        );
        insert stale;

        Test.setMock(HttpCalloutMock.class, new RetryMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Last_Polled__c FROM Checkout_Payment__c WHERE Id = :stale.Id
        ];
        System.assertEquals('Declined', after.Status__c, 'Left as it is');
        System.assertEquals(null, after.Last_Polled__c, 'And no callout spent on it');
    }

    @IsTest
    static void aDeclinedSessionIsNotPolled() {
        // Payment sessions carry no expiry and are never retried - the microsite mints a fresh
        // session, and a fresh row, per attempt. Excluding null expiry is what keeps them out.
        Checkout_Payment__c session = new Checkout_Payment__c(
            Reference__c = 'CKO-RETRY', Status__c = 'Declined',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Payment_Link_Id__c = 'ps_abc', Payment_Id__c = 'pay_dead'
        );
        insert session;

        Test.setMock(HttpCalloutMock.class, new RetryMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Last_Polled__c FROM Checkout_Payment__c WHERE Id = :session.Id
        ];
        System.assertEquals('Declined', after.Status__c, 'Left as it is');
        System.assertEquals(null, after.Last_Polled__c, 'A null expiry means a session, so no callout');
    }

    @IsTest
    static void anExpiredRowWithALiveLinkIsStillWatched() {
        // Checkout reports an abandoned attempt as Expired. The link is still open, so the customer
        // can come back and pay, exactly as CKO-c674fd6950b73af078 did in Production.
        Checkout_Payment__c abandoned = new Checkout_Payment__c(
            Reference__c = 'CKO-RETRY', Status__c = 'Expired',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Payment_Id__c = 'pay_abandoned',
            Expires_On__c = System.now().addHours(6)
        );
        insert abandoned;

        Test.setMock(HttpCalloutMock.class, new RetryMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Payment_Id__c FROM Checkout_Payment__c WHERE Id = :abandoned.Id
        ];
        System.assertEquals('Authorized', after.Status__c, 'The later attempt was picked up');
        System.assertEquals('pay_retry', after.Payment_Id__c, 'On its own payment id');
    }

    @IsTest
    static void aFreshSessionWithNoExpiryIsStillPolled() {
        // Checkout returns no expiry for a session, so age is the only signal. A new one is very
        // much live and must keep being watched.
        Checkout_Payment__c fresh = new Checkout_Payment__c(
            Reference__c = 'CKO-POLL', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Payment_Link_Id__c = 'ps_fresh'
        );
        insert fresh;

        Test.setMock(HttpCalloutMock.class, new PollMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Last_Polled__c FROM Checkout_Payment__c WHERE Id = :fresh.Id
        ];
        System.assertEquals('Captured', after.Status__c, 'A live session is polled and resolved');
        System.assertNotEquals(null, after.Last_Polled__c, 'Poll timestamp set');
    }

    @IsTest
    static void anUnpaidSessionStopsBeingPolledOnceItIsStale() {
        // Checkout returns no expiry for a session, so without an age rule these rows are polled
        // every cycle for the whole lookback and never reach a terminal status. Production was
        // carrying 45 of them.
        Checkout_Payment__c stale = new Checkout_Payment__c(
            Reference__c = 'CKO-POLL', Status__c = 'Link Created',
            Amount__c = 50000, Currency_Code__c = 'AED',
            Payment_Link_Id__c = 'ps_stale'
        );
        insert stale;
        Test.setCreatedDate(stale.Id, System.now().addDays(-3));

        Test.setMock(HttpCalloutMock.class, new PollMock());
        Test.startTest();
        Database.executeBatch(new CheckoutPaymentPoller(), 20);
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Last_Polled__c FROM Checkout_Payment__c WHERE Id = :stale.Id
        ];
        System.assertEquals('Expired', after.Status__c, 'Given up on, so it leaves the poll');
        System.assertEquals(null, after.Last_Polled__c, 'And no callout was spent deciding that');
    }
}