/**********************************************************************************************
 * Name           : CheckoutNotificationServiceTest
 * Description     : What each Checkout payment event says, and who it says it to.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    13 Sep 2026    Cover the wording, the origin split and the refund gate.
 **********************************************************************************************/
@IsTest(IsParallel=false)
private class CheckoutNotificationServiceTest {

    private class OutboundMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest request) {
            HttpResponse response = new HttpResponse();
            response.setStatusCode(200);
            response.setBody('{"message_id":"TEST-1"}');
            return response;
        }
    }

    private static Checkout_Payment__c payment(String reference, String status) {
        return new Checkout_Payment__c(
            Reference__c = reference, Status__c = status, Amount__c = 9000, Currency_Code__c = 'AED',
            Customer_Name__c = 'Prateek Bansal', Customer_Email__c = 'test.customer@example.com',
            Customer_Phone__c = '+971500000000',
            Payment_Link_Url__c = 'https://pay.sandbox.checkout.com/link/pl_testlink',
            Expires_On__c = System.now().addDays(1)
        );
    }

    /** CreatedBy.UserType cannot be assigned, so the origin fixture is built from JSON. */
    private static Checkout_Payment__c contextCreatedBy(String userType) {
        return (Checkout_Payment__c) JSON.deserialize(
            '{"attributes":{"type":"Checkout_Payment__c"},' +
            '"CreatedBy":{"attributes":{"type":"User"},"UserType":"' + userType + '"}}',
            Checkout_Payment__c.class
        );
    }

    @IsTest
    static void everyMoneyEventRoutesToItsOwnConfiguredRow() {
        // Wording moved to config, which differs per org, so assert the routing rather than the words.
        Map<String, String> typeByEvent = new Map<String, String>{
            'captured'     => 'Checkout Payment Captured',
            'refunded'     => 'Checkout Payment Refunded',
            'voided'       => 'Checkout Payment Voided',
            'hold_expired' => 'Checkout Hold Expired',
            'declined'     => 'Checkout Payment Declined'
        };
        Checkout_Payment__c row = payment('CKO-WORDING', 'Captured');
        insert row;
        for (String evt : typeByEvent.keySet()) {
            NotificationDispatcher.Message m = CheckoutNotificationService.buildMessage(row, evt);
            System.assertNotEquals(null, m, evt + ' must produce a message');
            System.assertEquals(typeByEvent.get(evt), m.messageType, evt + ' must name its own config row');
            System.assertEquals('noreply@modon.com', m.fromEmail, 'every customer mail uses the org-wide sender');
        }
    }

    @IsTest
    static void aLinkMessageWithNoLinkSaysNothing() {
        Checkout_Payment__c noUrl = payment('CKO-NOLINK', 'Link Created');
        noUrl.Payment_Link_Url__c = null;
        insert noUrl;
        System.assertEquals(null, CheckoutNotificationService.buildMessage(noUrl, 'created'),
            'a link message with no link says nothing at all');
    }

    @IsTest
    static void aMissingCustomerNameStillReadsProperly() {
        Checkout_Payment__c anonymous = payment('CKO-ANON', 'Captured');
        anonymous.Customer_Name__c = null;
        insert anonymous;
        NotificationDispatcher.Message m = CheckoutNotificationService.buildMessage(anonymous, 'captured');
        System.assertEquals('Customer', m.customerName, 'a nameless payer is greeted as Customer, never blank');
    }

    @IsTest
    static void theOriginFollowsWhoeverRaisedTheLink() {
        System.assertEquals(CheckoutNotificationService.ORIGIN_SITE,
            CheckoutNotificationService.originOf(contextCreatedBy('Guest')), 'a guest is the EOI microsite');
        System.assertEquals(CheckoutNotificationService.ORIGIN_BROKER,
            CheckoutNotificationService.originOf(contextCreatedBy('PowerPartner')), 'a partner user is a broker');
        System.assertEquals(CheckoutNotificationService.ORIGIN_SALES,
            CheckoutNotificationService.originOf(contextCreatedBy('Standard')), 'anyone else is Modon sales');
        System.assertEquals(CheckoutNotificationService.ORIGIN_SALES,
            CheckoutNotificationService.originOf(null), 'no context falls back to sales rather than throwing');
    }

    @IsTest
    static void anEoiBackedEndingIsTheEoiRailsToAnnounce() {
        for (String status : new List<String>{ 'Captured', 'Refunded', 'Voided', 'Authorization Expired' }) {
            Checkout_Payment__c backed = payment('CKO-EOI', status);
            backed.Expression_of_Interest__c = null;
            Checkout_Payment__c prior = payment('CKO-EOI', 'Authorized');

            System.assertNotEquals(null, CheckoutNotificationService.resolveEvent(backed, prior),
                status + ' on a payment with no EOI keeps its own wording');
        }
    }

    @IsTest
    static void nothingIsSaidWhenNothingChanged() {
        Checkout_Payment__c row = payment('CKO-SAME', 'Captured');
        System.assertEquals(null, CheckoutNotificationService.resolveEvent(row, payment('CKO-SAME', 'Captured')),
            'the same status twice is not an event');
        System.assertEquals(null, CheckoutNotificationService.resolveEvent(payment('CKO-NEW', 'Authorized'), null),
            'a row created straight into Authorized has no link to send');
        System.assertEquals('created', CheckoutNotificationService.resolveEvent(payment('CKO-NEW', 'Link Created'), null),
            'a new Link Created row is the one insert that speaks');
    }

    @IsTest
    static void aLapsedHoldIsNotAnExpiredLink() {
        Checkout_Payment__c lapsed = payment('CKO-HOLD', 'Expired');
        System.assertEquals('hold_expired',
            CheckoutNotificationService.resolveEvent(lapsed, payment('CKO-HOLD', 'Authorized')),
            'Expired from Authorized means the money was held and released');
        System.assertEquals('expired',
            CheckoutNotificationService.resolveEvent(lapsed, payment('CKO-HOLD', 'Link Created')),
            'Expired from Link Created means nobody ever paid');
    }

    @IsTest
    static void theLinkSmsFitsOneSegment() {
        String sms = CheckoutNotificationService.linkSms(
            'Prateek', 'AED 9,000', 'https://pay.sandbox.checkout.com/link/pl_testlink', '14 Sep 13:42');
        System.assert(CheckoutNotificationService.gsmLength(sms) <= CheckoutNotificationService.SMS_MAX_CHARS,
            'the link SMS must never split: ' + CheckoutNotificationService.gsmLength(sms) + ' chars');
        System.assert(sms.contains('pl_testlink'), 'and the link always survives the ladder');
    }

    @IsTest
    static void theSmsHelpersHandleTheAwkwardInputs() {
        System.assertEquals('Customer', CheckoutNotificationService.smsFirstName(null),
            'a blank name still greets somebody');
        System.assertEquals('Prateek', CheckoutNotificationService.smsFirstName('Prateek Bansal'),
            'only the first name is used, to save characters');
        System.assertEquals(null, CheckoutNotificationService.smsExpiry(null),
            'no expiry returns null, and linkSms drops the clause rather than printing it');
        System.assert(String.isNotBlank(CheckoutNotificationService.smsExpiry(System.now())),
            'a real expiry renders');
        System.assertEquals('AED 9,000', CheckoutNotificationService.toGsm('AED 9,000'),
            'plain GSM text passes through untouched');
    }

    @IsTest
    static void theWordingLadderPicksTheLongestThatFits() {
        String chosen = CheckoutNotificationService.fitSms(new List<String>{
            'x'.repeat(400), 'x'.repeat(200), 'short enough'
        });
        System.assertEquals('short enough', chosen, 'the ladder falls through to the first rung that fits');
    }

    @IsTest
    static void aReplacedRowIsSilencedWhateverItResolvesTo() {
        Checkout_Payment__c row = payment('CKO-REPLACED', 'Expired');
        insert row;
        Checkout_Payment__c prior = row.clone(true, true, false, false);
        prior.Status__c = 'Link Created';

        CheckoutNotificationService.replacedRowIds = new Set<Id>{ row.Id };
        Test.setMock(HttpCalloutMock.class, new OutboundMock());
        Test.startTest();
        CheckoutNotificationService.handle(
            new List<Checkout_Payment__c>{ row },
            new Map<Id, Checkout_Payment__c>{ row.Id => prior }
        );
        Test.stopTest();
        CheckoutNotificationService.replacedRowIds = new Set<Id>();

        System.assertEquals(0, [
            SELECT COUNT() FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :String.valueOf(row.Id) AND Message_Type__c = 'Checkout Link Expired'
        ], 'a row retired by a newer link must not tell the customer their link expired');
    }

    @IsTest
    static void resendLinkGoesOutAgainForALiveRow() {
        Checkout_Payment__c live = payment('CKO-RESEND', 'Link Created');
        Checkout_Payment__c dead = payment('CKO-DEAD', 'Expired');
        insert new List<Checkout_Payment__c>{ live, dead };

        Test.setMock(HttpCalloutMock.class, new OutboundMock());
        Test.startTest();
        Integer sentForLive = CheckoutNotificationService.resendLink(new Set<Id>{ live.Id });
        Integer sentForDead = CheckoutNotificationService.resendLink(new Set<Id>{ dead.Id });
        Integer sentForNone = CheckoutNotificationService.resendLink(new Set<Id>());
        Test.stopTest();

        System.assertEquals(1, sentForLive, 'a live link can be resent');
        System.assertEquals(0, sentForDead, 'an expired one cannot');
        System.assertEquals(0, sentForNone, 'and an empty request does nothing');
    }
}