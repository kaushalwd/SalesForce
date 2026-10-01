/**********************************************************************************************
 * Name           : CheckoutHoldRenewalQueueableTest
 * Description     : Coverage for the six-hourly hold renewal and recovery job. What matters is which row it picks:
 *                   a hold inside the threshold is renewed, a fresh or already-expired one is left
 *                   alone, a renewed hold is not picked up again, and a decline neither stalls the
 *                   chain nor disturbs the original hold.
 *                   Each test performs at most ONE renewal, because reauthorize ends in DML on both
 *                   outcomes and Apex forbids a callout after uncommitted work. That constraint is
 *                   the reason the job chains a queueable per row instead of looping.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.2        Prateek Bansal    22 Sep 2026    Covers the daily pacing on live holds, and that recovery escapes it.
 * 1.1        Prateek Bansal    21 Sep 2026    Covers recovery of a lapsed hold and the handover to the business.
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class CheckoutHoldRenewalQueueableTest {

    private class RenewalMock implements HttpCalloutMock {
        private final Boolean approve;
        public Integer paymentCalls = 0;
        RenewalMock(Boolean approve) { this.approve = approve; }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().endsWith('/voids')) {
                res.setStatusCode(202);
                res.setBody('{"action_id":"act_void"}');
                return res;
            }
            paymentCalls++;
            res.setStatusCode(201);
            res.setBody(approve
                ? '{"id":"pay_renewed","approved":true,"status":"Authorized",'
                    + '"expires_on":"2026-09-30T10:00:00Z",'
                    + '"source":{"id":"src_renewed","type":"card","last4":"4242","scheme":"Visa"}}'
                : '{"id":"pay_declined","approved":false,"status":"Declined",'
                    + '"response_summary":"Insufficient funds"}');
            return res;
        }
    }

    /** A held payment whose authorisation expires in daysOut days. */
    private static Checkout_Payment__c hold(String reference, String sourceId, Integer daysOut) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Authorized', Amount__c = 650000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_' + reference,
            Authorization_Expires_On__c = System.now().addDays(daysOut)
        );
        if (sourceId != null) cp.Source_Id__c = sourceId;
        insert cp;
        return cp;
    }

    @IsTest
    static void renewsOnlyHoldsInsideTheThreshold() {
        // 2 days out is inside the 4 day window; 8 days out is a fresh hold and must be left alone.
        Checkout_Payment__c due = hold('CKO-DUE', 'src_stored', 2);
        Checkout_Payment__c notDue = hold('CKO-FRESH', 'src_stored', 8);
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(false, more, 'Only one row qualified, so nothing is left to chain');
        System.assertEquals(1, mock.paymentCalls, 'Only the hold near expiry is renewed');
        System.assertEquals('pay_renewed',
            [SELECT Payment_Id__c FROM Checkout_Payment__c WHERE Id = :due.Id].Payment_Id__c,
            'The due hold carries the new authorisation');
        System.assertEquals('pay_CKO-FRESH',
            [SELECT Payment_Id__c FROM Checkout_Payment__c WHERE Id = :notDue.Id].Payment_Id__c,
            'The fresh hold is untouched');
    }

    @IsTest
    static void aRenewedHoldIsNotPickedUpAgain() {
        // The renewal response pushes Authorization_Expires_On__c forward, which is what takes the
        // row back out of the threshold. Without that, the job would renew the same hold every day.
        Checkout_Payment__c cp = hold('CKO-ONCE', 'src_stored', 1);
        Test.setMock(HttpCalloutMock.class, new RenewalMock(true));

        Test.startTest();
        CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        Checkout_Payment__c renewed = [
            SELECT Authorization_Expires_On__c FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals(
            Datetime.newInstanceGmt(2026, 9, 30, 10, 0, 0), renewed.Authorization_Expires_On__c,
            'The renewal stamps its own expiry, not the superseded one'
        );
        System.assertEquals(
            false, CheckoutHoldRenewalQueueable.runOne(new Set<Id>()),
            'With the expiry pushed out, a fresh run finds nothing to do'
        );
    }

    @IsTest
    static void skipsHoldsThatCannotBeRenewed() {
        // No stored instrument, and an authorisation that already expired: neither is renewable, and
        // selecting either would spend the run on a row that can never clear.
        hold('CKO-NOSRC', null, 2);
        hold('CKO-GONE', 'src_stored', -1);
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(false, more, 'Neither row is a candidate');
        System.assertEquals(0, mock.paymentCalls, 'Checkout is never called');
    }

    @IsTest
    static void aDeclineLeavesTheHoldStandingAndKeepsTheChainGoing() {
        Checkout_Payment__c first = hold('CKO-D1', 'src_stored', 1);
        hold('CKO-D2', 'src_stored', 2);
        RenewalMock mock = new RenewalMock(false);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Set<Id> attempted = new Set<Id>();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(attempted);
        Test.stopTest();

        System.assertEquals(1, mock.paymentCalls, 'One renewal per transaction');
        System.assertEquals(true, more, 'The second due hold is still waiting, so the chain continues');
        System.assertEquals(true, attempted.contains(first.Id),
            'The tried row is recorded, so the chain moves on instead of looping on a decline');
        System.assertEquals('pay_CKO-D1',
            [SELECT Payment_Id__c FROM Checkout_Payment__c WHERE Id = :first.Id].Payment_Id__c,
            'A declined renewal leaves the original hold untouched');
        System.assertEquals(2,
            [SELECT COUNT() FROM Checkout_Payment__c WHERE Status__c = 'Authorized'],
            'Both holds are still held');
    }

    @IsTest
    static void alreadyAttemptedRowsAreExcluded() {
        // Proves the chain terminates: once every due row is in the attempted set there is nothing
        // left to select, so a decline can never make the chain run forever.
        Checkout_Payment__c only = hold('CKO-SEEN', 'src_stored', 2);
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(new Set<Id>{ only.Id });
        Test.stopTest();

        System.assertEquals(false, more, 'The only due row was already tried');
        System.assertEquals(0, mock.paymentCalls, 'It is not renewed a second time');
    }

    @IsTest
    static void theSchedulerEnqueuesTheWork() {
        // Scheduled Apex cannot call out, so the scheduler only hands over to the queueable.
        Test.setMock(HttpCalloutMock.class, new RenewalMock(true));

        Test.startTest();
        String jobId = System.schedule(
            'Checkout Hold Renewal Test', '0 0 2 3 9 ? 2030', new CheckoutHoldRenewalScheduler());
        Test.stopTest();

        System.assertEquals(
            '0 0 2 3 9 ? 2030',
            [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId].CronExpression,
            'A plain cron expression schedules it - no self-rescheduling needed for a daily job'
        );
    }

    /** A hold that has already lapsed, expiring hoursAgo hours in the past. */
    private static Checkout_Payment__c lapsed(String reference, Integer hoursAgo) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Authorization Expired', Amount__c = 650000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_' + reference, Source_Id__c = 'src_stored',
            Customer_Email__c = 'recovery@example.com', Customer_Name__c = 'Recovery Test',
            Authorization_Expires_On__c = System.now().addHours(-hoursAgo)
        );
        insert cp;
        return cp;
    }

    @IsTest
    static void aLapsedHoldInsideTheWindowIsRecovered() {
        // The point of the whole design: once the hold has gone the card has full headroom, so the
        // retry needs the deposit once rather than twice.
        Checkout_Payment__c cp = lapsed('CKO-LAPSED', 6);
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        Checkout_Payment__c after = [
            SELECT Status__c, Payment_Id__c, Renewal_Attempts__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertEquals(1, mock.paymentCalls, 'The lapsed hold is retried');
        System.assertEquals('Authorized', after.Status__c,
            'A recovered hold goes back to Authorized, or the job would retry it forever');
        System.assertEquals('pay_renewed', after.Payment_Id__c, 'It carries the new authorisation');
        System.assertEquals(1, after.Renewal_Attempts__c, 'The attempt is counted');
    }

    @IsTest
    static void aLapsedHoldPastTheWindowIsHandedToTheBusiness() {
        // Three days gone is outside the two day window. Nothing is retried; the business is told and
        // the EOI is deliberately left open for them to chase.
        Checkout_Payment__c cp = lapsed('CKO-OLD', 72);
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(0, mock.paymentCalls, 'Checkout is never called for a hold we gave up on');
        System.assertEquals(true, more, 'The chain continues so the retry pass still gets a turn');
        System.assertEquals(true,
            [SELECT Recovery_Alert_Sent__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Recovery_Alert_Sent__c,
            'It is flagged as reported, so the business is emailed exactly once');
    }

    @IsTest
    static void aReportedHoldIsNeverTouchedAgain() {
        Checkout_Payment__c cp = lapsed('CKO-DONE', 6);
        cp.Recovery_Alert_Sent__c = true;
        update cp;
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(false, more, 'Nothing left to do');
        System.assertEquals(0, mock.paymentCalls, 'A reported hold is not retried or re-reported');
    }

    @IsTest
    static void aRowMarkedExpiredWhoseClockSaysOtherwiseIsLeftAlone() {
        // Seen in the live data: a row carrying Authorization Expired while Checkout still holds the
        // money. Taking a second hold on that card is the exact problem this job exists to avoid, so
        // the clock decides, not the label.
        lapsed('CKO-STILLLIVE', -24);
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(false, more, 'The hold has not actually lapsed yet');
        System.assertEquals(0, mock.paymentCalls, 'No second hold is taken on a live card');
    }

    @IsTest
    static void thePreExpiryCapNeverStarvesRecovery() {
        // The cap guards the pre-expiry phase only. A live hold that has used its attempts stops being
        // retried, while a lapsed one is still recovered however many attempts it burned earlier -
        // recovery is the phase that actually works, so it must never inherit an empty budget.
        Checkout_Payment__c spent = hold('CKO-PRE-CAPPED', 'src_stored', 1);
        spent.Renewal_Attempts__c = CheckoutHoldRenewalQueueable.MAX_PRE_EXPIRY_ATTEMPTS;
        update spent;
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(false, more, 'The only live hold has used its pre-expiry attempts');
        System.assertEquals(0, mock.paymentCalls, 'The cap stops another pre-expiry attempt');
    }

    // ── One schedule, two paces ──────────────────────────────────────────────

    @IsTest
    static void aLiveHoldTriedTodayIsNotTriedAgain() {
        // The job wakes every 6 hours for recovery's sake. A live hold must not inherit that rate:
        // the card is still holding the money, and the scheme's own guidance on an insufficient funds
        // decline is not to resubmit immediately.
        Checkout_Payment__c cp = hold('CKO-PACED', 'src_stored', 1);
        cp.Last_Renewal_Attempt__c = System.now().addHours(-1);
        update cp;
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        Boolean more = CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(false, more, 'Nothing is due until tomorrow');
        System.assertEquals(0, mock.paymentCalls,
            'A live hold tried an hour ago must wait, or a six-hourly cron renews it four times a day');
    }

    @IsTest
    static void aLiveHoldTriedYesterdayIsDueAgain() {
        // 21 hours clears the 20 hour pace. The gap is deliberately under 24: the job never fires at
        // the same instant twice, so an exact day would skip a night by a few seconds.
        Checkout_Payment__c cp = hold('CKO-DUE-AGAIN', 'src_stored', 1);
        cp.Last_Renewal_Attempt__c = System.now().addHours(-21);
        update cp;
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(1, mock.paymentCalls, 'The next night is allowed through');
        System.assertNotEquals(null,
            [SELECT Last_Renewal_Attempt__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Last_Renewal_Attempt__c,
            'Every attempt re-stamps the row, win or lose, or a failing card would be retried hourly');
    }

    @IsTest
    static void recoveryIgnoresTheDailyPace() {
        // The one that carries the risk. Recovery is the phase that actually works, and it is bounded
        // by its own two day window - if the pace leaked into it, eight attempts would become two.
        Checkout_Payment__c cp = lapsed('CKO-REC-PACED', 6);
        cp.Last_Renewal_Attempt__c = System.now().addHours(-1);
        update cp;
        RenewalMock mock = new RenewalMock(true);
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        CheckoutHoldRenewalQueueable.runOne(new Set<Id>());
        Test.stopTest();

        System.assertEquals(1, mock.paymentCalls,
            'A lapsed hold is retried on every run however recently it was tried');
        System.assertEquals('Authorized',
            [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id].Status__c,
            'And it still recovers');
    }
}