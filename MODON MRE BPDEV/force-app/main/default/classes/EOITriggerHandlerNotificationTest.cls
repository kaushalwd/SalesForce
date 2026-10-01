/**********************************************************************************************************************
* Name               : EOITriggerHandlerNotificationTest
* Description        : Which endings the EOI speaks on, and which it stays quiet for
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    13 Sep 2026     Cover the void wording, the refund gate and the one-job rule.
**********************************************************************************************************************/
@IsTest
private class EOITriggerHandlerNotificationTest {

    private static final String MSG_VOIDED = 'EOI Voided Notification';
    private static final String MSG_BROKER_VOIDED = 'Broker EOI Voided';
    private static final String MSG_CREATION = 'EOI Creation Confirmation';

    private class OutboundMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"message_id":"TEST-1"}');
            return response;
        }
    }

    /**
     * A phone on the account is what puts a message in the queue: with no way to reach anyone every
     * log is written Skipped and nothing is ever handed to a job. Source_Entity__c on the EOI is a
     * formula off the Opportunity, so the entity is set there.
     */
    private static List<Opportunity> buildOpportunities(List<String> names, String sourceEntity) {
        List<Account> accounts = new List<Account>();
        for (String who : names) accounts.add(new Account(Name = 'EOI Notify ' + who, Phone = '+971500000000'));
        insert accounts;

        List<Contact> people = new List<Contact>();
        for (Integer i = 0; i < names.size(); i++) {
            people.add(new Contact(LastName = names[i], Email = names[i] + '@example.com', AccountId = accounts[i].Id));
        }
        insert people;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < names.size(); i++) {
            Opportunity opp = new Opportunity(
                Name = 'EOI Notify ' + names[i],
                StageName = 'Discussion In Progress',
                CloseDate = Date.today().addDays(30),
                AccountId = accounts[i].Id,
                PrimaryContact__c = people[i].Id
            );
            if (sourceEntity != null) opp.Source_Entity__c = sourceEntity;
            opps.add(opp);
        }
        insert opps;
        return opps;
    }

    private static Opportunity buildOpportunity(String who, String sourceEntity) {
        return buildOpportunities(new List<String>{ who }, sourceEntity)[0];
    }

    private static Expressionofinterest__c buildEoi(String who, String sourceEntity) {
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = buildOpportunity(who, sourceEntity).Id,
            Status__c = 'Payment Authorized'
        );
        insert eoi;
        return eoi;
    }

    private static void payFor(Expressionofinterest__c eoi, String reference) {
        insert new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Voided', Amount__c = 9000, Currency_Code__c = 'AED',
            Customer_Name__c = 'Test Customer', Customer_Email__c = 'test.customer@example.com',
            Customer_Phone__c = '+971500000000', Expression_of_Interest__c = eoi.Id
        );
    }

    /**
     * The EOI trigger runs once per record per transaction: TriggerHandler.processedIds filters a
     * record out of every after-pass beyond its first. Production raises the EOI and closes it in
     * separate transactions, so the tests below clear the set to see what production sees.
     */
    private static void asANewTransaction() {
        TriggerHandler.processedIds = new Set<Id>();
    }

    private static List<Outbound_Message_Log__c> logsFor(Id eoiId, String messageType) {
        return [
            SELECT Channel__c, Message_Type__c, Status__c, Recipient__c
            FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :String.valueOf(eoiId) AND Message_Type__c = :messageType
        ];
    }

    private static void setStatus(Id eoiId, String status) {
        asANewTransaction();
        update new Expressionofinterest__c(Id = eoiId, Status__c = status);
    }

    @IsTest
    static void cancelledIsAnEndingAndTheCustomerAndBrokerBothHear() {
        Expressionofinterest__c eoi = buildEoi('CancelPaid', null);
        payFor(eoi, 'CKO-TEST-CANCEL');

        Test.setMock(HttpCalloutMock.class, new OutboundMock());
        Test.startTest();
        setStatus(eoi.Id, 'Cancelled');
        Test.stopTest();

        System.assert(!logsFor(eoi.Id, MSG_VOIDED).isEmpty(), 'Cancelled is what the cascade writes, so it must speak.');
        System.assert(!logsFor(eoi.Id, MSG_BROKER_VOIDED).isEmpty(), 'The broker hears their client is refunded too.');
    }

    @IsTest
    static void voidedStillWorksTheWayItAlwaysDid() {
        Expressionofinterest__c eoi = buildEoi('VoidPaid', null);
        payFor(eoi, 'CKO-TEST-VOID');

        Test.setMock(HttpCalloutMock.class, new OutboundMock());
        Test.startTest();
        setStatus(eoi.Id, 'Voided');
        Test.stopTest();

        System.assert(!logsFor(eoi.Id, MSG_VOIDED).isEmpty(), 'Widening to Cancelled must not cost the old wording.');
    }

    @IsTest
    static void nobodyIsPromisedARefundTheyNeverPaidFor() {
        Expressionofinterest__c eoi = buildEoi('CancelUnpaid', null);

        Test.startTest();
        setStatus(eoi.Id, 'Cancelled');
        Test.stopTest();

        System.assert(logsFor(eoi.Id, MSG_VOIDED).isEmpty(), 'No payment behind it means no refund to announce.');
        System.assert(logsFor(eoi.Id, MSG_BROKER_VOIDED).isEmpty(), 'The broker hears nothing either.');
    }

    @IsTest
    static void anExpiredEoiIsTheLinksNewsNotTheEois() {
        Expressionofinterest__c eoi = buildEoi('ExpiredOne', null);
        payFor(eoi, 'CKO-TEST-EXPIRED');

        Test.startTest();
        setStatus(eoi.Id, 'Expired');
        Test.stopTest();

        System.assert(logsFor(eoi.Id, MSG_VOIDED).isEmpty(),
            'Link expiry is a Checkout payment event and already has its own message.');
    }

    @IsTest
    static void theSameEndingIsOnlyAnnouncedOnce() {
        Expressionofinterest__c eoi = buildEoi('CancelTwice', null);
        payFor(eoi, 'CKO-TEST-TWICE');

        Test.setMock(HttpCalloutMock.class, new OutboundMock());
        Test.startTest();
        setStatus(eoi.Id, 'Cancelled');
        Integer firstPass = logsFor(eoi.Id, MSG_VOIDED).size();
        setStatus(eoi.Id, 'Voided');
        Test.stopTest();

        System.assertEquals(firstPass, logsFor(eoi.Id, MSG_VOIDED).size(),
            'A second ending on the same EOI must not repeat the message.');
    }

    @IsTest
    static void modonEgyptIsLeftOutOfThisEntirely() {
        Expressionofinterest__c eoi = buildEoi('EgyptOne', 'Modon - Egypt');
        payFor(eoi, 'CKO-TEST-EGYPT');

        Test.startTest();
        setStatus(eoi.Id, 'Cancelled');
        Test.stopTest();

        System.assert(logsFor(eoi.Id, MSG_VOIDED).isEmpty(), 'Modon Egypt runs its own communications.');
    }

    @IsTest
    static void cancellingManyAtOnceSpeaksToEveryOneOfThem() {
        List<String> names = new List<String>();
        for (Integer i = 0; i < 5; i++) names.add('Bulk' + i);
        List<Opportunity> opps = buildOpportunities(names, null);

        List<Expressionofinterest__c> eois = new List<Expressionofinterest__c>();
        for (Opportunity opp : opps) {
            eois.add(new Expressionofinterest__c(Opportunity__c = opp.Id, Status__c = 'Payment Authorized'));
        }
        insert eois;

        List<Checkout_Payment__c> payments = new List<Checkout_Payment__c>();
        for (Integer i = 0; i < eois.size(); i++) {
            payments.add(new Checkout_Payment__c(
                Reference__c = 'CKO-TEST-BULK-' + i, Status__c = 'Voided', Amount__c = 9000,
                Currency_Code__c = 'AED', Customer_Name__c = 'Test Customer',
                Customer_Email__c = 'test.customer@example.com', Customer_Phone__c = '+971500000000',
                Expression_of_Interest__c = eois[i].Id
            ));
        }
        insert payments;

        List<Expressionofinterest__c> toCancel = new List<Expressionofinterest__c>();
        for (Expressionofinterest__c eoi : eois) {
            toCancel.add(new Expressionofinterest__c(Id = eoi.Id, Status__c = 'Cancelled'));
        }

        Test.setMock(HttpCalloutMock.class, new OutboundMock());
        Test.startTest();
        asANewTransaction();
        update toCancel;
        Test.stopTest();

        for (Expressionofinterest__c eoi : eois) {
            System.assert(!logsFor(eoi.Id, MSG_VOIDED).isEmpty(), 'Every EOI in the batch is told, not just the first.');
        }
    }

    /**
     * The guard behind CP-00231. An async transaction gets one queueable, and the poller raises every
     * pay-first EOI from one, so a second request would throw a limit exception that no catch holds
     * and take the EOI insert with it.
     */
    @IsTest
    static void everyMessageANewEoiRaisesSharesOneJob() {
        Opportunity opp = buildOpportunity('OneJob', null);

        Test.startTest();
        Integer before = Limits.getQueueableJobs();
        insert new Expressionofinterest__c(Opportunity__c = opp.Id, Status__c = 'Payment Authorized');
        System.assertEquals(1, Limits.getQueueableJobs() - before,
            'Creation, the finance offer and the broker copy go out on a single job.');
        Test.stopTest();
    }

    @IsTest
    static void aNewEoiStillRaisesItsThreeMessages() {
        Test.setMock(HttpCalloutMock.class, new OutboundMock());
        Test.startTest();
        Expressionofinterest__c eoi = buildEoi('ThreeMessages', null);
        Test.stopTest();

        System.assert(!logsFor(eoi.Id, MSG_CREATION).isEmpty(), 'The confirmation still goes out.');
        System.assert(!logsFor(eoi.Id, 'EOI Finance Pre-Approval').isEmpty(), 'So does the finance offer.');
        System.assert(!logsFor(eoi.Id, 'Broker EOI Registered').isEmpty(), 'And the broker copy.');
    }
}