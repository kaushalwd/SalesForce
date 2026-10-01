/**
 * MBP_EoiTableActionsTest - Aurelix IT, 11 Sep 2026 (BP-057 / BP-058 / BP-060)
 *
 * The broker EOI table's row actions: Resend link, Send new link and Cancel. Every test runs as a
 * broker portal user, so the agency scoping and the system-mode reads are exercised for real.
 *
 * BP-060: Send new link CREATES a second payment request and retires the spent one, so the tests
 * below prove both records - the new one's own reference, number and stored interest, and the old
 * one keeping its history while offering nothing.
 *
 * Its own class, and its own agency, on purpose. MBP_EoiPaymentLinkControllerTest seeds a large
 * fixture and the org's Account / Opportunity / Task automation is query-hungry, so adding rows to
 * that class's setup ran unrelated tests into the SOQL governor limit. Nothing here can reach it.
 */
@IsTest
private class MBP_EoiTableActionsTest {

    private static final String PARTNER_PROFILE = 'Modon - Partner Community Login User';

    private class CheckoutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('/payment-links')) {
                res.setStatusCode(201);
                res.setBody('{"id":"pl_renewed999","_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/link/pl_renewed999"}}}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(422);
            res.setBody('{"error_type":"request_invalid"}');
            return res;
        }
    }

    @TestSetup
    static void seed() {
        Account agency = new Account(Name = 'BP057 Agency');
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1];
        if (!rts.isEmpty()) agency.RecordTypeId = rts[0].Id;
        Account otherAgency = new Account(Name = 'BP057 Other Agency');
        if (!rts.isEmpty()) otherAgency.RecordTypeId = rts[0].Id;
        Account customer = new Account(Name = 'BP057 Customer', Phone = '+971500000009');
        insert new List<Account>{ agency, otherAgency, customer };

        Contact owner = new Contact(LastName = 'BpOwner', AccountId = agency.Id, Email = 'bp057owner@example.com', Broker_Type__c = 'Owner');
        Contact buyer = new Contact(AccountId = customer.Id, FirstName = 'Cust', LastName = 'Omer',
                                    Email = 'customer@example.com', MobilePhone = '+971500000001');
        insert new List<Contact>{ owner, buyer };

        SObject project = Schema.getGlobalDescribe().get('Project__c').newSObject();
        project.put('Name', 'BP057 Project');
        insert project;

        Opportunity mine = newOpportunity('BP057 Opp', customer.Id, buyer.Id, agency.Id, owner.Id);
        Opportunity theirs = newOpportunity('BP057 Foreign Opp', customer.Id, buyer.Id, otherAgency.Id, null);
        insert new List<Opportunity>{ mine, theirs };

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = mine.Id, Project__c = (Id) project.get('Id'), Account__c = customer.Id, Contact__c = buyer.Id,
            EOI_Amount_AED__c = 6000, Payment_Type__c = 'Online', Status__c = 'Payment Authorized',
            Number_of_Units__c = 1, EOIComments__c = 'BP058-HELD'
        );
        putIfFieldExists(eoi, 'BrokerAgency__c', agency.Id);
        putIfFieldExists(eoi, 'BrokerAgent__c', owner.Id);
        insert eoi;

        /* Only the rows whose test actually calls out are seeded here: a test cannot insert a record
           and then call out in the same transaction. Every refusal case builds its own row. */
        Checkout_Payment__c live = row(mine.Id, (Id) project.get('Id'), 'Link Created', System.now().addHours(6), 'slot-live');
        live.Reference__c = 'BP057-LIVE';
        Checkout_Payment__c lapsed = row(mine.Id, (Id) project.get('Id'), 'Link Created', System.now().addHours(-1), 'slot-lapsed');
        lapsed.Reference__c = 'BP057-LAPSED';
        Checkout_Payment__c expired = row(mine.Id, (Id) project.get('Id'), 'Expired', System.now().addHours(-2), 'slot-expired');
        expired.Reference__c = 'BP057-EXPIRED';
        expired.Payment_Id__c = 'pay_previous_attempt';
        expired.Source_Id__c = 'src_previous';
        expired.Card_Last4__c = '4242';
        expired.Last_Checkout_Status__c = 'Expired';
        Checkout_Payment__c held = row(mine.Id, (Id) project.get('Id'), 'Authorized', System.now().addDays(1), 'slot-held');
        held.Reference__c = 'BP058-HELD';
        held.Payment_Id__c = 'pay_held_123';
        held.Expression_of_Interest__c = eoi.Id;
        insert new List<Checkout_Payment__c>{ live, lapsed, expired, held };

        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert newPortalUser('bp057own', owner.Id);
        }
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private static void putIfFieldExists(SObject record, String field, Object value) {
        if (record.getSObjectType().getDescribe().fields.getMap().containsKey(field)) record.put(field, value);
    }

    private static Opportunity newOpportunity(String name, Id accountId, Id contactId, Id agencyId, Id agentContactId) {
        Opportunity o = new Opportunity(Name = name, StageName = 'Discussion In Progress', CloseDate = Date.today().addDays(10), AccountId = accountId);
        putIfFieldExists(o, 'ContactId', contactId);
        putIfFieldExists(o, 'PrimaryContact__c', contactId);
        putIfFieldExists(o, 'BrokerAgency__c', agencyId);
        putIfFieldExists(o, 'BrokerAgent__c', agentContactId);
        return o;
    }

    private static User newPortalUser(String alias, Id contactId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :PARTNER_PROFILE LIMIT 1];
        Id roleId;
        List<UserRole> roles = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1];
        if (!roles.isEmpty()) roleId = roles[0].Id;
        return new User(
            FirstName = 'BP057', LastName = alias, Email = alias + '@example.com',
            Username = alias + DateTime.now().getTime() + '@example.com', Alias = alias.right(8),
            TimeZoneSidKey = 'Asia/Dubai', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = p.Id, ContactId = contactId, UserRoleId = roleId, IsActive = true
        );
    }

    /** A broker payment request exactly as createInterestLink writes one. */
    private static Checkout_Payment__c row(Id opportunityId, Id projectId, String status, Datetime expiresOn) {
        return row(opportunityId, projectId, status, expiresOn, 'interest-1');
    }

    /* BP-060 retires every request for an interest but the newest, so a fixture row that is meant to
       stand on its own carries its own slot - one opportunity, several interests, exactly as a broker
       raises them. Tests that need the supersede rule pass the SAME slot on purpose. */
    private static Checkout_Payment__c row(Id opportunityId, Id projectId, String status, Datetime expiresOn, String slot) {
        String payload = JSON.serialize(new Map<String, Object>{
            'opportunityId' => String.valueOf(opportunityId), 'projectId' => String.valueOf(projectId),
            'unitType' => 'Villa', 'bedrooms' => '4 Bedrooms', 'numberOfUnits' => 1,
            'eoiAmount' => 6000, 'paymentType' => 'Online', 'currencyCode' => 'AED', 'brokerSlot' => slot
        });
        return new Checkout_Payment__c(
            Related_Record_Id__c = String.valueOf(opportunityId), Status__c = status, Amount__c = 6000,
            Currency_Code__c = 'AED', Customer_Name__c = 'Cust Omer', Customer_Email__c = 'customer@example.com',
            Customer_Phone__c = '+971500000001', EOI_Creation_Payload__c = payload, Expires_On__c = expiresOn,
            Portal_Initiated__c = true, Capture_Mode__c = 'Authorize',
            Payment_Link_Url__c = 'https://pay.sandbox.checkout.com/link/pl_seeded'
        );
    }

    private static User broker() {
        return [SELECT Id FROM User WHERE FirstName = 'BP057' AND LastName = 'bp057own' LIMIT 1];
    }

    /* Looked up by agency, not by name: the org renames Opportunities through its own automation. */
    private static Id myOppId() {
        return [SELECT Id FROM Opportunity WHERE BrokerAgency__r.Name = 'BP057 Agency' LIMIT 1].Id;
    }

    private static Id foreignOppId() {
        return [SELECT Id FROM Opportunity WHERE BrokerAgency__r.Name = 'BP057 Other Agency' LIMIT 1].Id;
    }

    private static Id projectId() {
        return [SELECT Id FROM Project__c WHERE Name = 'BP057 Project' LIMIT 1].Id;
    }

    private static Checkout_Payment__c payment(String reference) {
        return [
            SELECT Id, Name, Status__c, Reference__c, Amount__c, Payment_Link_Id__c, Payment_Link_Url__c,
                   Expires_On__c, Payment_Id__c, Source_Id__c, Card_Last4__c, Last_Checkout_Status__c,
                   Expression_of_Interest__c, Related_Record_Id__c, EOI_Creation_Payload__c, CreatedDate,
                   Customer_Email__c
            FROM Checkout_Payment__c WHERE Reference__c = :reference LIMIT 1
        ];
    }

    private static Integer paymentsFor(String reference) {
        return [SELECT COUNT() FROM Checkout_Payment__c WHERE Reference__c = :reference];
    }

    /** Every payment request raised against one opportunity, whatever its status. */
    private static Integer paymentsOn(Id opportunityId) {
        String related = String.valueOf(opportunityId);
        return [SELECT COUNT() FROM Checkout_Payment__c WHERE Related_Record_Id__c = :related];
    }

    /** What the customer was actually sent about one payment request. */
    private static Integer messagesAbout(Id paymentId) {
        String related = String.valueOf(paymentId);
        return [SELECT COUNT() FROM Outbound_Message_Log__c WHERE Related_Record_Id__c = :related];
    }

    /** A row a refusal test acts on. A refusal makes no callout, so it can be inserted in the test. */
    private static Checkout_Payment__c seedRow(Id opportunityId, String status, String reference, String paymentIdValue) {
        return seedRow(opportunityId, status, reference, paymentIdValue, reference);
    }

    private static Checkout_Payment__c seedRow(Id opportunityId, String status, String reference, String paymentIdValue, String slot) {
        Checkout_Payment__c cp = row(opportunityId, projectId(), status, System.now().addDays(1), slot);
        cp.Reference__c = reference;
        if (String.isNotBlank(paymentIdValue)) cp.Payment_Id__c = paymentIdValue;
        insert cp;
        return cp;
    }

    // ── BP-057: Send link ────────────────────────────────────────────────────

    @IsTest
    static void sendLinkReSendsTheSameUrlAndLeavesTheClockAlone() {
        Checkout_Payment__c before = payment('BP057-LIVE');
        String name;
        System.runAs(broker()) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            name = MBP_EoiPaymentLinkController.resendBrokerLink(before.Id);
            Test.stopTest();
        }
        Checkout_Payment__c after = payment('BP057-LIVE');
        System.assertEquals(before.Name, name, 'the broker gets the CP number back');
        System.assertEquals(before.Payment_Link_Url__c, after.Payment_Link_Url__c, 'the same URL is sent again');
        System.assertEquals(before.Expires_On__c, after.Expires_On__c, 're-sending never extends the clock');
        System.assertEquals('Link Created', after.Status__c, 'and the status does not move');
        System.assertEquals(1, paymentsFor('BP057-LIVE'), 'no second payment row is created');
    }

    @IsTest
    static void sendLinkRefusesOnceTheClockHasRunOut() {
        Id lapsed = payment('BP057-LAPSED').Id;
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.resendBrokerLink(lapsed);
                System.assert(false, 'a dead link must not be re-sent');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('This link has expired. Use Send new link to issue a new one.', message,
            'the stored status still says Link Created, but the clock decides');
    }

    @IsTest
    static void sendLinkRefusesAnotherAgencysRequest() {
        Id other = seedRow(foreignOppId(), 'Link Created', 'BP057-OTHER-A', null).Id;
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.resendBrokerLink(other);
                System.assert(false, 'one agency must not reach another');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('You do not have access to this payment request.', message);
    }

    // ── BP-060: Send new link ────────────────────────────────────────────────

    @IsTest
    static void sendNewLinkCreatesASecondRequestAndRetiresTheSpentOne() {
        Checkout_Payment__c before = payment('BP057-EXPIRED');
        Integer wasOnOpp = paymentsOn(myOppId());
        MBP_EoiPaymentLinkController.NewLinkResult created;
        System.runAs(broker()) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            created = MBP_EoiPaymentLinkController.renewBrokerLink(before.Id);
            Test.stopTest();
        }

        Checkout_Payment__c spent = payment('BP057-EXPIRED');
        System.assertEquals(before.Id, spent.Id, 'the spent request keeps its record');
        System.assertEquals(before.Name, spent.Name, 'and its number');
        System.assertEquals('BP057-EXPIRED', spent.Reference__c, 'and its reference');
        System.assertEquals('Expired', spent.Status__c, 'it is retired, never reused');
        System.assertEquals(before.Payment_Link_Url__c, spent.Payment_Link_Url__c, 'its dead link stays as history');
        System.assertEquals(1, paymentsFor('BP057-EXPIRED'), 'its reference still names exactly one row');

        System.assertNotEquals(null, created, 'the broker is handed the new request');
        System.assertNotEquals(null, created.paymentId);
        Checkout_Payment__c fresh = [
            SELECT Id, Name, Status__c, Reference__c, Amount__c, Currency_Code__c, Payment_Link_Id__c,
                   Payment_Link_Url__c, Expires_On__c, Related_Record_Id__c, EOI_Creation_Payload__c,
                   Expression_of_Interest__c, Portal_Initiated__c, Customer_Email__c
            FROM Checkout_Payment__c WHERE Id = :created.paymentId
        ];
        System.assertEquals(fresh.Name, created.paymentName, 'and the number its message names');
        System.assertNotEquals(before.Id, fresh.Id, 'a SECOND record, as MODON asked');
        System.assertNotEquals(before.Name, fresh.Name, 'with its own number');
        System.assertNotEquals(before.Reference__c, fresh.Reference__c, 'and its OWN reference');
        System.assert(String.isNotBlank(fresh.Reference__c),
            'never blank, or the webhook would match the payment to the wrong row');
        System.assertEquals('Link Created', fresh.Status__c, 'payable');
        System.assertEquals('pl_renewed999', fresh.Payment_Link_Id__c, 'against the link just minted');
        System.assertEquals(true, fresh.Expires_On__c > System.now(), 'with a live expiry of its own');
        System.assertEquals(before.Amount__c, fresh.Amount__c, 'the same amount');
        System.assertEquals(before.Customer_Email__c, fresh.Customer_Email__c, 'the same customer');
        System.assertEquals(before.EOI_Creation_Payload__c, fresh.EOI_Creation_Payload__c,
            'and the same stored interest, so paying it raises the right EOI');
        System.assertEquals(String.valueOf(myOppId()), fresh.Related_Record_Id__c);
        System.assertEquals(false, fresh.Portal_Initiated__c, 'so the rail sends the link itself');
        System.assertEquals(null, fresh.Expression_of_Interest__c, 'no EOI until the money is held');
        System.assertEquals(wasOnOpp + 1, paymentsOn(myOppId()), 'exactly one new request, never two');
    }

    @IsTest
    static void theCustomerIsToldOnceAndNeverThatTheirNewLinkExpired() {
        Checkout_Payment__c before = payment('BP057-LAPSED');
        MBP_EoiPaymentLinkController.NewLinkResult created;
        System.runAs(broker()) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            created = MBP_EoiPaymentLinkController.renewBrokerLink(before.Id);
            Test.stopTest();
        }
        /* The spent row is retired inside the same transaction, so the table reads true at once
           instead of waiting for the poller - and the customer is never told their link expired
           moments after being sent a new one. */
        Checkout_Payment__c spent = payment('BP057-LAPSED');
        System.assertEquals('Expired', spent.Status__c,
            'the row still read Link Created, but its clock had run out');
        System.assertEquals('Expired', spent.Last_Checkout_Status__c);
        System.assertEquals(0, messagesAbout(spent.Id), 'and nothing was sent about the request it replaced');
        System.assert(messagesAbout(created.paymentId) > 0, 'the customer is told about the new request');
        System.assertEquals(true, CheckoutNotificationService.replacedRowIds.isEmpty(),
            'the suppression is lifted again, so nothing else in the transaction goes quiet');
    }

    @IsTest
    static void sendNewLinkIsRefusedWhileTheLinkIsStillLive() {
        Id live = payment('BP057-LIVE').Id;
        Integer was = paymentsOn(myOppId());
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.renewBrokerLink(live);
                System.assert(false, 'a live link must not be replaced');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('This payment request still has a live link. Use Resend link to send it again.', message);
        System.assertEquals(was, paymentsOn(myOppId()), 'and nothing was created');
    }

    @IsTest
    static void sendNewLinkIsRefusedOnceANewerRequestExists() {
        Checkout_Payment__c older = seedRow(myOppId(), 'Expired', 'BP060-REPLACED', null, 'slot-replaced');
        seedRow(myOppId(), 'Link Created', 'BP060-REPLACEMENT', null, 'slot-replaced');
        // the replacement was raised later for the same interest, so this one is spent
        Test.setCreatedDate(older.Id, System.now().addHours(-6));
        Integer was = paymentsOn(myOppId());
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.renewBrokerLink(older.Id);
                System.assert(false, 'a replaced request must not be able to raise another');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('A newer payment request has already been sent for this interest.', message);
        System.assertEquals(was, paymentsOn(myOppId()), 'so one interest never carries two live asks');
    }

    @IsTest
    static void aReplacedRequestIsStillListedAndOffersNothing() {
        Checkout_Payment__c older = seedRow(myOppId(), 'Expired', 'BP060-LISTED', null, 'slot-listed');
        seedRow(myOppId(), 'Link Created', 'BP060-LISTED-NEW', null, 'slot-listed');
        Test.setCreatedDate(older.Id, System.now().addHours(-6));
        List<MBP_EoiPaymentLinkController.PendingRow> rows;
        System.runAs(broker()) {
            Test.startTest();
            rows = MBP_EoiPaymentLinkController.getBrokerPendingLinks();
            Test.stopTest();
        }
        Boolean listed = false;
        Integer actionable = 0;
        for (MBP_EoiPaymentLinkController.PendingRow r : rows) {
            if (r.paymentId == older.Id) {
                listed = true;
                System.assertEquals(true, r.superseded, 'the replaced request offers nothing');
                System.assertEquals('BP060-LISTED', payment('BP060-LISTED').Reference__c);
            } else if (r.superseded != true) {
                actionable++;
            }
        }
        System.assertEquals(true, listed, 'it keeps its number and its history in the table');
        System.assert(actionable > 0, 'the newest request for the interest is still actionable');
    }

    @IsTest
    static void sendNewLinkNeverShowsCheckoutsOwnWordingAndChangesNothing() {
        Checkout_Payment__c before = payment('BP057-EXPIRED');
        Integer was = paymentsOn(myOppId());
        String message;
        System.runAs(broker()) {
            Test.setMock(HttpCalloutMock.class, new FailureMock());
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.renewBrokerLink(before.Id);
                System.assert(false, 'a Checkout error must stop the action');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('The payment link could not be created. Please try again.', message,
            'the gateway status code never reaches a broker screen');
        Checkout_Payment__c after = payment('BP057-EXPIRED');
        System.assertEquals('Expired', after.Status__c, 'and the row is left exactly as it was');
        System.assertEquals(before.Payment_Link_Url__c, after.Payment_Link_Url__c);
        System.assertEquals(was, paymentsOn(myOppId()), 'with nothing created');
    }

    @IsTest
    static void sendNewLinkRefusesAnotherAgencysRequest() {
        Id other = seedRow(foreignOppId(), 'Expired', 'BP057-OTHER-B', null).Id;
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.renewBrokerLink(other);
                System.assert(false, 'one agency must not reach another');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('You do not have access to this payment request.', message);
    }

    // ── BP-058: Cancel ───────────────────────────────────────────────────────

    @IsTest
    static void cancelReleasesTheHoldAndTheEoiClosesItself() {
        Checkout_Payment__c before = payment('BP058-HELD');
        System.assertEquals('Payment Authorized',
            [SELECT Status__c FROM Expressionofinterest__c WHERE EOIComments__c = 'BP058-HELD'].Status__c,
            'the EOI starts open');
        String name;
        System.runAs(broker()) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            name = MBP_EoiPaymentLinkController.cancelBrokerPayment(before.Id);
            Test.stopTest();
        }
        Checkout_Payment__c after = payment('BP058-HELD');
        System.assertEquals(before.Name, name, 'the broker gets the CP number back');
        System.assertEquals('Voided', after.Status__c, 'the hold is released and the row says so');
        System.assertEquals('Voided', after.Last_Checkout_Status__c);
        System.assertEquals(before.Id, after.Id, 'the same record, never a new one');

        Expressionofinterest__c eoi = [
            SELECT Status__c, SLA_Voided_Reason__c FROM Expressionofinterest__c WHERE EOIComments__c = 'BP058-HELD'
        ];
        System.assertEquals('Cancelled', eoi.Status__c, 'the EOI closed itself through the lapsed-hold rail');
        System.assert(String.isNotBlank(eoi.SLA_Voided_Reason__c), 'with a reason for finance');
        System.assert(eoi.SLA_Voided_Reason__c.contains('BP058-HELD'), 'naming the payment reference: ' + eoi.SLA_Voided_Reason__c);
    }

    @IsTest
    static void cancelIsRefusedOnceTheMoneyIsTaken() {
        Id taken = seedRow(myOppId(), 'Captured', 'BP058-TAKEN', 'pay_taken_123').Id;
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.cancelBrokerPayment(taken);
                System.assert(false, 'a captured payment must not be reversed from the portal');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('This payment has already been completed and cannot be cancelled.', message);
        System.assertEquals('Captured', payment('BP058-TAKEN').Status__c, 'and the row is untouched');
    }

    @IsTest
    static void cancelIsRefusedOnARequestNobodyHasPaid() {
        Id live = payment('BP057-LIVE').Id;
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.cancelBrokerPayment(live);
                System.assert(false, 'there is no hold to release');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('This payment can no longer be cancelled.', message);
        System.assertEquals('Link Created', payment('BP057-LIVE').Status__c);
    }

    @IsTest
    static void cancelIsRefusedWithoutACheckoutPaymentId() {
        Id noPayId = seedRow(myOppId(), 'Authorized', 'BP058-NOPAYID', null).Id;
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.cancelBrokerPayment(noPayId);
                System.assert(false, 'without a payment id there is nothing to void at Checkout');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('This payment cannot be cancelled yet. Please try again shortly.', message);
        System.assertEquals('Authorized', payment('BP058-NOPAYID').Status__c, 'and nothing was changed');
    }

    @IsTest
    static void cancelIsRefusedOnAnotherAgencysPayment() {
        Id other = seedRow(foreignOppId(), 'Authorized', 'BP058-OTHER', 'pay_other_123').Id;
        String message;
        System.runAs(broker()) {
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.cancelBrokerPayment(other);
                System.assert(false, 'one agency must not reach another');
            } catch (AuraHandledException e) { message = e.getMessage(); }
            Test.stopTest();
        }
        System.assertEquals('You do not have access to this payment request.', message);
    }

    @IsTest
    static void everyRowActionRefusesANullPayment() {
        System.runAs(broker()) {
            Test.startTest();
            try { MBP_EoiPaymentLinkController.resendBrokerLink(null); System.assert(false); }
            catch (AuraHandledException e) { System.assertEquals('Something went wrong. Please try again.', e.getMessage()); }
            try { MBP_EoiPaymentLinkController.renewBrokerLink(null); System.assert(false); }
            catch (AuraHandledException e) { System.assertEquals('Something went wrong. Please try again.', e.getMessage()); }
            try { MBP_EoiPaymentLinkController.cancelBrokerPayment(null); System.assert(false); }
            catch (AuraHandledException e) { System.assertEquals('Something went wrong. Please try again.', e.getMessage()); }
            Test.stopTest();
        }
    }
}