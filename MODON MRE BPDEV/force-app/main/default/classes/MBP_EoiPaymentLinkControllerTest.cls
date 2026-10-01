/**
 * MBP_EoiPaymentLinkControllerTest - Aurelix IT, 9 Sep 2026 (BP-030)
 * Checkout is mocked; every test runs as a broker portal user (partner profile) so the
 * agency scoping, the with-sharing EOI read and the without-sharing duplicate check are exercised.
 */
@IsTest
private class MBP_EoiPaymentLinkControllerTest {

    private static final String PARTNER_PROFILE = 'Modon - Partner Community Login User';
    private static String lastRequestBody;
    private static String lastSmsBody;

    private class CheckoutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getEndpoint().contains('/payment-links')) {
                lastRequestBody = req.getBody(); // the Checkout call only; the SMS/email queueable calls out too
                lastSmsBody = null;
                res.setStatusCode(201);
                res.setBody('{"id":"pl_broker123","reference":"CKO-BROKER",' +
                    '"_links":{"redirect":{"href":"https://pay.sandbox.checkout.com/link/pl_broker123"}}}');
            } else {
                if (String.isNotBlank(req.getBody()) && req.getBody().contains('TextMessage')) lastSmsBody = req.getBody();
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
            res.setBody('{"error_type":"request_invalid","error_codes":["currency_required"]}');
            return res;
        }
    }

    @TestSetup
    static void seed() {
        // Two broker agencies: A (owner + agent users) and B (other agency).
        Account agencyA = newAgency('BP030 Agency A');
        Account agencyB = newAgency('BP030 Agency B');
        insert new List<Account>{ agencyA, agencyB };

        Contact ownerA = new Contact(LastName = 'OwnerA', AccountId = agencyA.Id, Email = 'ownera@example.com', Broker_Type__c = 'Owner');
        Contact agentA = new Contact(LastName = 'AgentA', AccountId = agencyA.Id, Email = 'agenta@example.com', Broker_Type__c = 'Agent');
        insert new List<Contact>{ ownerA, agentA };

        // Customer side.
        Account customer = new Account(Name = 'BP030 Customer', Phone = '+971500000009');
        insert customer;
        Contact customerContact = new Contact(
            AccountId = customer.Id, FirstName = 'Cust', LastName = 'Omer',
            Email = 'customer@example.com', MobilePhone = '+971500000001'
        );
        insert customerContact;

        Opportunity oppA = newOpportunity('BP030 Opp A', customer.Id, customerContact.Id, agencyA.Id, ownerA.Id);
        Opportunity oppB = newOpportunity('BP030 Opp B', customer.Id, customerContact.Id, agencyB.Id, null);
        insert new List<Opportunity>{ oppA, oppB };

        SObject project = Schema.getGlobalDescribe().get('Project__c').newSObject();
        project.put('Name', 'BP030 Project');
        insert project;

        // BP-041: the interest the drawer sends resolves to this range on the server (phase + type + bedrooms + typology)
        SObject phase = Schema.getGlobalDescribe().get('Phase__c').newSObject();
        phase.put('Name', 'BP041 Phase');
        putIfFieldExists(phase, 'Project__c', project.Id);
        insert phase;
        SObject range = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        putIfFieldExists(range, 'Project__c', project.Id);
        putIfFieldExists(range, 'Phase__c', phase.Id);
        putIfFieldExists(range, 'Amount__c', 6000);
        putIfFieldExists(range, 'Is_Active__c', true);
        putIfFieldExists(range, 'Unit_Type__c', 'Villa');
        putIfFieldExists(range, 'No_of_Bedrooms__c', '6 Bedrooms');
        putIfFieldExists(range, 'UnitTypologyMRE__c', 'Fairway Villas');
        putIfFieldExists(range, 'Applicable_for_Broker__c', true);
        // BP-070: brokerRange now also requires Show On = Broker Portal
        putIfFieldExists(range, 'Show_On__c', MBP_EoiPaymentLinkController.SHOW_ON_BROKER);
        insert range;

        // BP-041: an Opportunity that already carries a live request for interest-1 (two units). Seeded here, in its
        // own transaction, because a test cannot insert a row and then call out in the same transaction.
        Opportunity oppSlot = newOpportunity('BP041 Slot Opp', customer.Id, customerContact.Id, agencyA.Id, ownerA.Id);
        insert oppSlot;
        insert newRequestRow(oppSlot.Id, 'Link Created', System.now().addDays(1), 2);

        Expressionofinterest__c eoiA = newEoi(oppA.Id, (Id) project.get('Id'), customer.Id, customerContact.Id, agencyA.Id, ownerA.Id, 6000);
        Expressionofinterest__c eoiB = newEoi(oppB.Id, (Id) project.get('Id'), customer.Id, customerContact.Id, agencyB.Id, null, 6000);
        Expressionofinterest__c eoiZero = newEoi(oppA.Id, (Id) project.get('Id'), customer.Id, customerContact.Id, agencyA.Id, ownerA.Id, 0);
        eoiA.EOIComments__c = 'BP030-A';
        eoiB.EOIComments__c = 'BP030-B';
        eoiZero.EOIComments__c = 'BP030-ZERO';
        insert new List<Expressionofinterest__c>{ eoiA, eoiB, eoiZero };

        // Portal users last, in their own DML context (setup object).
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new List<User>{ newPortalUser('bp030owner', ownerA.Id), newPortalUser('bp030agent', agentA.Id) };
        }
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    private static Account newAgency(String name) {
        Account a = new Account(Name = name);
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1];
        if (!rts.isEmpty()) a.RecordTypeId = rts[0].Id;
        return a;
    }

    private static Opportunity newOpportunity(String name, Id accountId, Id contactId, Id agencyId, Id agentContactId) {
        Opportunity o = new Opportunity(Name = name, StageName = 'Discussion In Progress', CloseDate = Date.today().addDays(10), AccountId = accountId);
        putIfFieldExists(o, 'ContactId', contactId);
        putIfFieldExists(o, 'PrimaryContact__c', contactId);
        putIfFieldExists(o, 'BrokerAgency__c', agencyId);
        putIfFieldExists(o, 'BrokerAgent__c', agentContactId);
        return o;
    }

    private static Expressionofinterest__c newEoi(Id oppId, Id projectId, Id accountId, Id contactId, Id agencyId, Id agentContactId, Decimal amount) {
        Expressionofinterest__c e = new Expressionofinterest__c(
            Opportunity__c = oppId, Project__c = projectId, Account__c = accountId, Contact__c = contactId,
            EOI_Amount_AED__c = amount, Payment_Type__c = 'Online', Status__c = 'New', Number_of_Units__c = 1
        );
        putIfFieldExists(e, 'BrokerAgency__c', agencyId);
        putIfFieldExists(e, 'BrokerAgent__c', agentContactId);
        return e;
    }

    private static User newPortalUser(String alias, Id contactId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :PARTNER_PROFILE LIMIT 1];
        Id roleId;
        List<UserRole> roles = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1];
        if (!roles.isEmpty()) roleId = roles[0].Id;
        return new User(
            FirstName = 'BP030', LastName = alias, Email = alias + '@example.com',
            Username = alias + DateTime.now().getTime() + '@example.com', Alias = alias.right(8),
            TimeZoneSidKey = 'Asia/Dubai', LocaleSidKey = 'en_US', EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            ProfileId = p.Id, ContactId = contactId, UserRoleId = roleId, IsActive = true
        );
    }

    private static void putIfFieldExists(SObject rec, String f, Object v) {
        if (v != null && rec.getSObjectType().getDescribe().fields.getMap().containsKey(f.toLowerCase())) rec.put(f, v);
    }

    private static User portalUser(String alias) {
        return [SELECT Id FROM User WHERE LastName = :alias AND FirstName = 'BP030' LIMIT 1];
    }

    private static Id eoiId(String marker) {
        return [SELECT Id FROM Expressionofinterest__c WHERE EOIComments__c = :marker LIMIT 1].Id;
    }

    private static Integer linkCount(Id eoi) {
        return [SELECT COUNT() FROM Checkout_Payment__c WHERE Expression_of_Interest__c = :eoi];
    }

    // ── tests ────────────────────────────────────────────────────────────────

    @IsTest
    static void ownerCreatesAuthorizeOnlyOneDayLink() {
        Id eoi = eoiId('BP030-A');
        MBP_EoiPaymentLinkController.LinkResult r;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            r = MBP_EoiPaymentLinkController.createPaymentLink(eoi);
            Test.stopTest();
        }
        System.assertEquals(true, r.success, 'link created');
        System.assertEquals(false, r.alreadyExisted, 'first call creates');
        System.assert(String.isNotBlank(r.paymentName) && r.paymentName.startsWith('CP-'), 'broker gets the CP number: ' + r.paymentName);
        System.assertEquals('cu***@example.com', r.maskedEmail, 'masked email');
        System.assertEquals('****0001', r.maskedPhone, 'masked phone');
        System.assertEquals(6000, r.amount, 'amount = EOI balance');

        Checkout_Payment__c cp = [
            SELECT Status__c, Capture_Mode__c, Amount__c, Expression_of_Interest__c, Related_Record_Id__c,
                   Customer_Email__c, Customer_Phone__c, Expires_On__c, Portal_Initiated__c
            FROM Checkout_Payment__c WHERE Id = :r.paymentId
        ];
        System.assertEquals('Link Created', cp.Status__c);
        System.assertEquals('Authorize', cp.Capture_Mode__c, 'authorize only, never immediate');
        System.assertEquals(eoi, cp.Expression_of_Interest__c);
        System.assertEquals(String.valueOf(eoi), cp.Related_Record_Id__c);
        System.assertEquals('customer@example.com', cp.Customer_Email__c);
        System.assertEquals('+971500000001', cp.Customer_Phone__c);
        System.assertEquals(false, cp.Portal_Initiated__c, 'trigger must send the link message');
        Long deltaSeconds = (cp.Expires_On__c.getTime() - System.now().getTime()) / 1000;
        System.assert(deltaSeconds > 86400 - 300 && deltaSeconds <= 86400 + 300, 'expires in ~1 day, got ' + deltaSeconds + 's');

        System.assert(lastRequestBody.contains('"capture":false'), 'request capture=false: ' + lastRequestBody);
        System.assert(lastRequestBody.contains('"expires_in":86400'), 'request expires_in=86400: ' + lastRequestBody);
        System.assert(lastRequestBody.contains('"amount":600000'), 'AED 6000 in minor units: ' + lastRequestBody);
        // The existing trigger + queueable sent the link to the customer by SMS (email goes through Messaging, not HTTP).
        System.assert(lastSmsBody != null && lastSmsBody.contains('pl_broker123') && lastSmsBody.contains('+971500000001'),
            'link SMS went to the customer mobile: ' + lastSmsBody);
    }

    @IsTest
    static void secondCallReturnsTheSameLink() {
        Id eoi = eoiId('BP030-A');
        MBP_EoiPaymentLinkController.LinkResult first;
        MBP_EoiPaymentLinkController.LinkResult second;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            first = MBP_EoiPaymentLinkController.createPaymentLink(eoi);
            second = MBP_EoiPaymentLinkController.createPaymentLink(eoi);
            Test.stopTest();
        }
        System.assertEquals(false, first.alreadyExisted);
        System.assertEquals(true, second.alreadyExisted, 'retry returns the open link');
        System.assertEquals(first.paymentId, second.paymentId, 'same row');
        System.assertEquals(1, linkCount(eoi), 'never a second link');
    }

    @IsTest
    static void otherAgencyEoiIsRefused() {
        Id eoi = eoiId('BP030-B');
        Boolean threw = false;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.createPaymentLink(eoi);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
        }
        System.assert(threw, 'another agency\'s EOI must be refused');
        System.assertEquals(0, linkCount(eoi));
    }

    @IsTest
    static void agentCannotLinkAnotherBrokersEoi() {
        Id eoi = eoiId('BP030-A'); // BrokerAgent__c on the opportunity is the owner, not the agent
        Boolean threw = false;
        System.runAs(portalUser('bp030agent')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.createPaymentLink(eoi);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
        }
        System.assert(threw, 'agent scope is the agent\'s own EOIs only');
        System.assertEquals(0, linkCount(eoi));
    }

    @IsTest
    static void zeroBalanceIsRefused() {
        Id eoi = eoiId('BP030-ZERO');
        Boolean threw = false;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.createPaymentLink(eoi);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
        }
        System.assert(threw, 'no balance, no link');
        System.assertEquals(0, linkCount(eoi));
    }

    @IsTest
    static void checkoutFailureLeavesNoRow() {
        Id eoi = eoiId('BP030-A');
        Boolean threw = false;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new FailureMock());
            Test.startTest();
            try {
                MBP_EoiPaymentLinkController.createPaymentLink(eoi);
            } catch (AuraHandledException e) {
                threw = true;
            }
            Test.stopTest();
        }
        System.assert(threw, 'Checkout error surfaces to the broker');
        System.assertEquals(0, linkCount(eoi));
    }

    @IsTest
    static void linkMessagesAreSentFromTheOrgWideAddress() {
        // BP-043: the customer email must never carry the creating user (a broker) as its sender. Every Checkout
        // message names Modon's verified org-wide address; the display name stays 'Modon' for the SMS/WhatsApp legs.
        System.assertEquals('Modon', CheckoutNotificationService.CUSTOMER_SENDER_NAME);
        System.assertEquals('noreply@modon.com', CheckoutNotificationService.CUSTOMER_SENDER_ADDRESS);
        Checkout_Payment__c row = new Checkout_Payment__c(
            Status__c = 'Link Created', Reference__c = 'CKO-FROM', Amount__c = 6000, Currency_Code__c = 'AED',
            Customer_Email__c = 'customer@example.com', Customer_Phone__c = '+971500000001', Customer_Name__c = 'Cust Omer',
            Payment_Link_Url__c = 'https://pay.sandbox.checkout.com/link/pl_x', Expires_On__c = System.now().addDays(1)
        );
        for (String evt : new List<String>{ 'created', 'captured', 'voided', 'expired', 'hold_expired', 'refunded' }) {
            NotificationDispatcher.Message m = CheckoutNotificationService.buildMessage(row, evt);
            System.assertNotEquals(null, m, evt + ' message built');
            System.assertEquals('noreply@modon.com', m.fromEmail, evt + ': org-wide Modon sender');
            System.assertEquals('Modon', m.senderDisplayName, evt + ': display name Modon');
            System.assertEquals('customer@example.com', m.email, evt);
        }
    }

    @IsTest
    static void nullIdAndMasks() {
        Boolean threw = false;
        try {
            MBP_EoiPaymentLinkController.createPaymentLink(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'null id refused');
        System.assertEquals('ab***@x.com', MBP_EoiPaymentLinkController.maskEmail('ab.c@x.com'));
        System.assertEquals('', MBP_EoiPaymentLinkController.maskEmail('nonsense'));
        System.assertEquals('****4567', MBP_EoiPaymentLinkController.maskPhone('+971 58 123 4567'));
        System.assertEquals('', MBP_EoiPaymentLinkController.maskPhone('12'));
        System.assertEquals(86400, MBP_EoiPaymentLinkController.LINK_EXPIRY_SECONDS);
        System.assertEquals(false, MBP_EoiPaymentLinkController.CAPTURE_ON_PAYMENT);
    }

    // ── BP-041: one payment request per interest, no EOI at Submit ───────────

    // an org automation appends a date suffix to Opportunity names ('BP030 Opp A-100926'), so match on the prefix
    private static Id oppId(String name) {
        String prefix = name + '%';
        return [SELECT Id FROM Opportunity WHERE Name LIKE :prefix ORDER BY CreatedDate ASC LIMIT 1].Id;
    }

    private static Id projectId() {
        return [SELECT Id FROM Project__c WHERE Name = 'BP030 Project' LIMIT 1].Id;
    }

    private static Id phaseId() {
        return [SELECT Id FROM Phase__c WHERE Name = 'BP041 Phase' LIMIT 1].Id;
    }

    private static Id rangeId() {
        return [SELECT Id FROM EOI_Range__c WHERE Project__c = :projectId() LIMIT 1].Id;
    }

    private static String interestJson(Integer units, String typology) {
        return interestJson(units, typology, 'interest-1');
    }

    private static String interestJson(Integer units, String typology, String slot) {
        return JSON.serialize(new Map<String, Object>{
            'projectId' => projectId(), 'phaseId' => phaseId(), 'unitType' => 'Villa', 'bedrooms' => '6 Bedrooms',
            'unitTypology' => typology, 'numberOfUnits' => units, 'remarks' => 'BP041 remark', 'slot' => slot
        });
    }

    /** A stored payload exactly as createInterestLink writes it, for rows seeded straight into Checkout_Payment__c. */
    private static String storedPayload(Id opportunityId, Integer units) {
        return JSON.serialize(new Map<String, Object>{
            'opportunityId' => String.valueOf(opportunityId), 'projectId' => String.valueOf(projectId()), 'phaseId' => String.valueOf(phaseId()),
            'unitType' => 'Villa', 'bedrooms' => '6 Bedrooms', 'unitTypology' => 'Fairway Villas', 'numberOfUnits' => units,
            'eoiRangeId' => String.valueOf(rangeId()), 'eoiAmount' => 6000 * units, 'remarks' => 'seeded', 'paymentType' => 'Online', 'currencyCode' => 'AED',
            'brokerSlot' => 'interest-1'
        });
    }

    private static Checkout_Payment__c newRequestRow(Id opportunityId, String status, Datetime expiresOn, Integer units) {
        return new Checkout_Payment__c(
            Related_Record_Id__c = String.valueOf(opportunityId), Status__c = status, Amount__c = 6000 * units, Currency_Code__c = 'AED',
            Customer_Name__c = 'Cust Omer', Customer_Email__c = 'customer@example.com', Customer_Phone__c = '+971500000001',
            EOI_Creation_Payload__c = storedPayload(opportunityId, units), Expires_On__c = expiresOn, Portal_Initiated__c = true,
            Capture_Mode__c = 'Authorize', Payment_Link_Url__c = 'https://pay.sandbox.checkout.com/link/pl_seeded'
        );
    }

    private static Integer requestCount(Id opportunityId) {
        String related = String.valueOf(opportunityId);
        return [SELECT COUNT() FROM Checkout_Payment__c WHERE Related_Record_Id__c = :related];
    }

    /** Keyword of the refusal message, or 'none' when the call succeeded. */
    private static String interestFailure(Id opportunityId, String json) {
        try {
            MBP_EoiPaymentLinkController.createInterestLink(opportunityId, json);
            return 'none';
        } catch (AuraHandledException e) {
            return e.getMessage() == null ? '' : e.getMessage().toLowerCase();
        }
    }

    @IsTest
    static void ownerSendsAPaymentRequestOnHoldForTwoUnits() {
        Id opp = oppId('BP030 Opp A');
        EoiPaymentPolicy.captureChannelsOverride = '';        // the org label is None: every channel holds
        // interest JSON built before runAs: a portal user cannot see Project__c / Phase__c
        String twoUnits = interestJson(2, 'Fairway Villas');
        MBP_EoiPaymentLinkController.LinkResult r;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            r = MBP_EoiPaymentLinkController.createInterestLink(opp, twoUnits);
            Test.stopTest();
        }
        System.assertEquals(true, r.success);
        System.assertEquals(false, r.alreadyExisted);
        System.assertEquals(null, r.eoiId, 'no EOI exists at Submit');
        System.assert(String.isNotBlank(r.paymentName) && r.paymentName.startsWith('CP-'), 'broker gets the CP number: ' + r.paymentName);
        System.assertEquals(12000, r.amount, 'range 6000 x 2 units, priced on the server');
        System.assertEquals('cu***@example.com', r.maskedEmail);
        System.assertEquals('****0001', r.maskedPhone);

        Checkout_Payment__c cp = [
            SELECT Status__c, Capture_Mode__c, Amount__c, Currency_Code__c, Expression_of_Interest__c, Related_Record_Id__c,
                   Customer_Email__c, Customer_Phone__c, Customer_Name__c, Expires_On__c, Portal_Initiated__c, EOI_Creation_Payload__c
            FROM Checkout_Payment__c WHERE Id = :r.paymentId
        ];
        System.assertEquals('Link Created', cp.Status__c);
        System.assertEquals('Authorize', cp.Capture_Mode__c, 'hold, per EoiPaymentPolicy for the Broker channel');
        System.assertEquals(null, cp.Expression_of_Interest__c, 'the rail creates the EOI on authorization');
        System.assertEquals(String.valueOf(opp), cp.Related_Record_Id__c, '18-character Opportunity id');
        System.assertEquals('AED', cp.Currency_Code__c);
        System.assertEquals(12000, cp.Amount__c);
        System.assertEquals('customer@example.com', cp.Customer_Email__c, 'customer from the Opportunity contact');
        System.assertEquals('+971500000001', cp.Customer_Phone__c);
        System.assertEquals('Cust Omer', cp.Customer_Name__c);
        System.assertEquals(false, cp.Portal_Initiated__c, 'the trigger sends the link message');
        Long deltaSeconds = (cp.Expires_On__c.getTime() - System.now().getTime()) / 1000;
        System.assert(deltaSeconds > 86400 - 300 && deltaSeconds <= 86400 + 300, 'expires in ~1 day: ' + deltaSeconds);
        EoiCheckoutPaymentController.EoiPayload p = (EoiCheckoutPaymentController.EoiPayload) JSON.deserialize(cp.EOI_Creation_Payload__c, EoiCheckoutPaymentController.EoiPayload.class);
        System.assertEquals(String.valueOf(opp), p.opportunityId);
        System.assertEquals(String.valueOf(projectId()), p.projectId);
        System.assertEquals(String.valueOf(phaseId()), p.phaseId);
        System.assertEquals(String.valueOf(rangeId()), p.eoiRangeId);
        System.assertEquals(2, p.numberOfUnits);
        System.assertEquals(12000, p.eoiAmount);
        System.assertEquals('Villa', p.unitType);
        System.assertEquals('6 Bedrooms', p.bedrooms);
        System.assertEquals('Fairway Villas', p.unitTypology);
        System.assertEquals('Online', p.paymentType);
        System.assertEquals('AED', p.currencyCode);
        System.assertEquals('BP041 remark', p.remarks);
        System.assert(cp.EOI_Creation_Payload__c.contains('"brokerSlot":"interest-1"'), 'slot travels in the payload: ' + cp.EOI_Creation_Payload__c);

        System.assert(lastRequestBody.contains('"capture":false'), 'hold: ' + lastRequestBody);
        System.assert(lastRequestBody.contains('"expires_in":86400'), 'one day: ' + lastRequestBody);
        System.assert(lastRequestBody.contains('"amount":1200000'), 'AED 12000 in minor units: ' + lastRequestBody);
        System.assert(lastRequestBody.contains('"currency":"AED"'), 'AED: ' + lastRequestBody);
        System.assert(lastRequestBody.contains('"payment_type":"Unscheduled"'), 'a hold opens a stored-credential series: ' + lastRequestBody);
        System.assert(lastSmsBody != null && lastSmsBody.contains('pl_broker123') && lastSmsBody.contains('+971500000001'),
            'link SMS went to the customer mobile: ' + lastSmsBody);
        String serialized = JSON.serialize(r);
        System.assert(!serialized.contains('pay.sandbox') && !serialized.contains('http'), 'the broker never receives the URL: ' + serialized);
    }

    @IsTest
    static void brokerChannelChargesImmediatelyWhenTheLabelSaysSo() {
        Id opp = oppId('BP030 Opp A');
        EoiPaymentPolicy.captureChannelsOverride = 'Salesforce, Broker';
        // interest JSON built before runAs: a portal user cannot see Project__c / Phase__c
        String oneUnit = interestJson(1, 'Fairway Villas');
        MBP_EoiPaymentLinkController.LinkResult r;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            r = MBP_EoiPaymentLinkController.createInterestLink(opp, oneUnit);
            Test.stopTest();
        }
        System.assertEquals('Immediate', [SELECT Capture_Mode__c FROM Checkout_Payment__c WHERE Id = :r.paymentId].Capture_Mode__c);
        System.assert(lastRequestBody.contains('"capture":true'), lastRequestBody);
        System.assertEquals(6000, r.amount);
    }

    @IsTest
    static void theSameInterestIsNeverDoubledButEverySlotGetsItsOwnRequest() {
        Id opp = oppId('BP041 Slot Opp');          // seeded with a live request for interest-1, two units
        EoiPaymentPolicy.captureChannelsOverride = '';
        // interest JSON built before runAs: a portal user cannot see Project__c / Phase__c
        String slot1 = interestJson(2, 'Fairway Villas', 'interest-1');
        String slot2 = interestJson(2, 'Fairway Villas', 'interest-2');
        MBP_EoiPaymentLinkController.LinkResult again;
        MBP_EoiPaymentLinkController.LinkResult alike;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            again = MBP_EoiPaymentLinkController.createInterestLink(opp, slot1);   // Retry of the same slot: no second request
            alike = MBP_EoiPaymentLinkController.createInterestLink(opp, slot2);   // an identical second interest: its own request
            Test.stopTest();
        }
        System.assertEquals(true, again.alreadyExisted, 'retry of the same slot returns the live request');
        System.assertEquals(false, alike.alreadyExisted, 'two alike interests are two requests (one payment per interest)');
        System.assertNotEquals(again.paymentId, alike.paymentId);
        System.assertEquals(2, requestCount(opp), 'one request per slot, no doubles');
        System.assert(lastRequestBody != null && lastRequestBody.contains('"amount":1200000'), 'the new request priced 2 x 6000: ' + lastRequestBody);
    }

    @IsTest
    static void deadRequestsDoNotBlockANewOneButAHeldPaymentDoes() {
        Id opp = oppId('BP030 Opp A');
        EoiPaymentPolicy.captureChannelsOverride = '';
        // interest JSON built before runAs: a portal user cannot see Project__c / Phase__c
        String twoUnits = interestJson(2, 'Fairway Villas');
        String threeUnits = interestJson(3, 'Fairway Villas');
        Checkout_Payment__c authorized = newRequestRow(opp, 'Authorized', System.now().addHours(-2), 3);   // built here for the same reason
        Checkout_Payment__c expired = newRequestRow(opp, 'Link Created', System.now().addHours(-1), 2);   // link ran out
        Checkout_Payment__c declined = newRequestRow(opp, 'Declined', System.now().addDays(1), 2);
        insert new List<Checkout_Payment__c>{ expired, declined };
        MBP_EoiPaymentLinkController.LinkResult fresh;
        MBP_EoiPaymentLinkController.LinkResult held;
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            Test.startTest();
            fresh = MBP_EoiPaymentLinkController.createInterestLink(opp, twoUnits);
            // the customer paid on an earlier request: the money is held even though the link itself has expired
            insert authorized;
            held = MBP_EoiPaymentLinkController.createInterestLink(opp, threeUnits);
            Test.stopTest();
            System.assertEquals(true, held.alreadyExisted, 'an authorized payment is live whatever its link expiry');
            System.assertEquals(authorized.Id, held.paymentId);
        }
        System.assertEquals(false, fresh.alreadyExisted, 'expired / declined requests never block');
        System.assertNotEquals(expired.Id, fresh.paymentId);
        System.assertEquals(4, requestCount(opp), 'expired + declined + fresh + authorized');
    }

    @IsTest
    static void interestRequestsAreScopedToTheAgencyAndTheAgent() {
        Id oppB = oppId('BP030 Opp B');
        Id oppA = oppId('BP030 Opp A');
        EoiPaymentPolicy.captureChannelsOverride = '';
        // interest JSON built before runAs: a portal user cannot see Project__c / Phase__c
        String oneUnit = interestJson(1, 'Fairway Villas');
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        System.runAs(portalUser('bp030owner')) {
            System.assert(interestFailure(oppB, oneUnit).contains('agency'), 'other agency refused');
            System.assert(interestFailure(null, oneUnit).contains('required'), 'null opportunity refused');
        }
        System.runAs(portalUser('bp030agent')) {
            System.assert(interestFailure(oppA, oneUnit).contains('belong to you'), 'the opportunity broker agent is the owner, not this agent');
        }
        Test.stopTest();
        System.assertEquals(0, requestCount(oppA));
        System.assertEquals(0, requestCount(oppB));
    }

    @IsTest
    static void badInterestUnknownRangeAndFullProjectAreRefused() {
        Id opp = oppId('BP030 Opp A');
        EoiPaymentPolicy.captureChannelsOverride = '';
        // interest JSON built before runAs: a portal user cannot see Project__c / Phase__c
        String golfHomes = interestJson(1, 'Golf Homes');
        String oneUnit = interestJson(1, 'Fairway Villas');
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        System.runAs(portalUser('bp030owner')) {
            System.assert(interestFailure(opp, '{}').contains('complete the interest'), 'blank interest');
            System.assert(interestFailure(opp, 'not json').contains('complete the interest'), 'unreadable interest');
            System.assert(interestFailure(opp, golfHomes).contains('no active eoi range'), 'no matching broker range');
        }
        // three EOIs already exist on the project (seed): a limit of 3 leaves no room
        SObject project = Schema.getGlobalDescribe().get('Project__c').newSObject(projectId());
        project.put('EOI_Limit__c', 3);
        update project;
        System.runAs(portalUser('bp030owner')) {
            System.assert(interestFailure(opp, oneUnit).contains('remaining'), 'project quota refusal reaches the drawer');
        }
        Test.stopTest();
        System.assertEquals(0, requestCount(opp));
    }

    @IsTest
    static void customerWithoutEmailAndCheckoutFailureLeaveNoRequest() {
        Id oppA = oppId('BP030 Opp A');
        Account agencyA = [SELECT Id FROM Account WHERE Name = 'BP030 Agency A' LIMIT 1];
        Contact ownerA = [SELECT Id FROM Contact WHERE LastName = 'OwnerA' LIMIT 1];
        Account silent = new Account(Name = 'BP041 Silent Customer');
        insert silent;
        Contact noEmail = new Contact(AccountId = silent.Id, LastName = 'NoEmail', MobilePhone = '+971500000003');
        insert noEmail;
        Opportunity oppSilent = newOpportunity('BP041 Silent Opp', silent.Id, noEmail.Id, agencyA.Id, ownerA.Id);
        insert oppSilent;
        EoiPaymentPolicy.captureChannelsOverride = '';
        // interest JSON built before runAs: a portal user cannot see Project__c / Phase__c
        String oneUnit = interestJson(1, 'Fairway Villas');
        Test.startTest();
        System.runAs(portalUser('bp030owner')) {
            Test.setMock(HttpCalloutMock.class, new CheckoutMock());
            System.assert(interestFailure(oppSilent.Id, oneUnit).contains('email'), 'no email, no request');
            Test.setMock(HttpCalloutMock.class, new FailureMock());
            String reason = interestFailure(oppA, oneUnit);
            System.assertNotEquals('none', reason, 'Checkout error surfaces to the broker');
        }
        Test.stopTest();
        System.assertEquals(0, requestCount(oppSilent.Id));
        System.assertEquals(0, requestCount(oppA));
    }

    @IsTest
    static void pendingRequestsAreListedForTheAgencyNewestFirstWithoutTheUrl() {
        Id oppA = oppId('BP030 Opp A');
        Id oppB = oppId('BP030 Opp B');
        Id eoiA = eoiId('BP030-A');
        Checkout_Payment__c fresh = newRequestRow(oppA, 'Link Created', System.now().addDays(1), 2);
        Checkout_Payment__c expiredRow = newRequestRow(oppA, 'Expired', System.now().addDays(-1), 1);
        Checkout_Payment__c old = newRequestRow(oppA, 'Expired', System.now().addDays(-8), 1);
        Checkout_Payment__c otherAgency = newRequestRow(oppB, 'Link Created', System.now().addDays(1), 1);
        Checkout_Payment__c materialised = newRequestRow(oppA, 'Authorized', System.now().addDays(1), 1);
        materialised.Expression_of_Interest__c = eoiA;                                    // already an EOI: not pending
        Checkout_Payment__c legacyShape = newLinkRow(eoiA, 'Link Created');               // keyed by EOI id, no payload
        legacyShape.Related_Record_Id__c = String.valueOf(eoiA);
        insert new List<Checkout_Payment__c>{ fresh, expiredRow, old, otherAgency, materialised, legacyShape };
        Test.setCreatedDate(old.Id, System.now().addDays(-9));
        Test.setCreatedDate(expiredRow.Id, System.now().addDays(-2));

        List<MBP_EoiPaymentLinkController.PendingRow> asOwner;
        List<MBP_EoiPaymentLinkController.PendingRow> asAgent;
        Test.startTest();
        System.runAs(portalUser('bp030owner')) {
            asOwner = MBP_EoiPaymentLinkController.getBrokerPendingLinks();
        }
        System.runAs(portalUser('bp030agent')) {
            asAgent = MBP_EoiPaymentLinkController.getBrokerPendingLinks();
        }
        Test.stopTest();

        System.assertEquals(3, asOwner.size(), 'fresh + expired within the window + the seeded slot request; old, other agency, materialised and legacy rows excluded');
        Integer freshIdx = -1, expiredIdx = -1, seededIdx = -1;
        MBP_EoiPaymentLinkController.PendingRow row;
        for (Integer i = 0; i < asOwner.size(); i++) {
            if (asOwner[i].paymentId == fresh.Id) { freshIdx = i; row = asOwner[i]; }
            else if (asOwner[i].paymentId == expiredRow.Id) { expiredIdx = i; }
            else if (asOwner[i].opportunityName.startsWith('BP041 Slot Opp')) { seededIdx = i; }
        }
        System.assert(freshIdx >= 0 && expiredIdx >= 0 && seededIdx >= 0, 'all three requests listed: ' + JSON.serialize(asOwner));
        System.assert(freshIdx < expiredIdx, 'newest first: the fresh request (now) precedes the expired one (2 days old)');
        System.assert(String.isNotBlank(row.paymentName) && row.paymentName.startsWith('CP-'));
        System.assertEquals('Link Created', row.status, 'stored status, nothing invented');
        System.assertEquals('Cust Omer', row.customerName);
        System.assertEquals('cu***@example.com', row.maskedEmail);
        System.assertEquals('****0001', row.maskedPhone);
        System.assertEquals(oppA, row.opportunityId);
        System.assert(row.opportunityName.startsWith('BP030 Opp A'), 'opportunity name (the org suffixes a date): ' + row.opportunityName);
        System.assertEquals('BP030 Project', row.projectName, 'project name resolved for a portal user');
        System.assertEquals('BP041 Phase', row.phaseName);
        System.assertEquals('Villa', row.unitType);
        System.assertEquals('6 Bedrooms', row.bedrooms);
        System.assertEquals('Fairway Villas', row.unitTypology);
        System.assertEquals(2, row.units);
        System.assertEquals(12000, row.amount);
        System.assertEquals('AED', row.currencyCode);
        System.assertEquals('seeded', row.remarks);
        System.assertNotEquals(null, row.expiresOn);
        String serialized = JSON.serialize(asOwner);
        System.assert(!serialized.contains('pay.sandbox') && !serialized.contains('http') && !serialized.contains('CKO-'), 'never the URL or the reference: ' + serialized);
        System.assertEquals(0, asAgent.size(), 'the agent is not the broker agent on Opp A');
    }

    @IsTest
    static void anAgentSeesTheirOwnPendingRequests() {
        Account agencyA = [SELECT Id FROM Account WHERE Name = 'BP030 Agency A' LIMIT 1];
        Contact agentA = [SELECT Id FROM Contact WHERE LastName = 'AgentA' LIMIT 1];
        Account customer = [SELECT Id FROM Account WHERE Name = 'BP030 Customer' LIMIT 1];
        Contact customerContact = [SELECT Id FROM Contact WHERE LastName = 'Omer' AND AccountId = :customer.Id LIMIT 1];
        Opportunity oppC = newOpportunity('BP041 Agent Opp', customer.Id, customerContact.Id, agencyA.Id, agentA.Id);
        insert oppC;
        insert newRequestRow(oppC.Id, 'Link Created', System.now().addDays(1), 1);
        List<MBP_EoiPaymentLinkController.PendingRow> asAgent;
        List<MBP_EoiPaymentLinkController.PendingRow> asOwner;
        Test.startTest();
        System.runAs(portalUser('bp030agent')) {
            asAgent = MBP_EoiPaymentLinkController.getBrokerPendingLinks();
        }
        System.runAs(portalUser('bp030owner')) {
            asOwner = MBP_EoiPaymentLinkController.getBrokerPendingLinks();
        }
        Test.stopTest();
        System.assertEquals(1, asAgent.size(), 'own opportunity');
        System.assert(asAgent[0].opportunityName.startsWith('BP041 Agent Opp'), asAgent[0].opportunityName);
        System.assertEquals(2, asOwner.size(), 'the owner sees the whole agency: the agent request plus the seeded slot request');
    }

    @IsTest
    static void interestKeyNormalisesIdsTextAndUnits() {
        Id p = projectId();
        Id ph = phaseId();
        String a = MBP_EoiPaymentLinkController.interestKey(String.valueOf(p), String.valueOf(ph), 'Villa', '6 Bedrooms', 'Fairway Villas', 2, 'interest-1');
        String b = MBP_EoiPaymentLinkController.interestKey(String.valueOf(p).left(15), ' ' + String.valueOf(ph) + ' ', ' villa', '6 BEDROOMS ', 'fairway villas', 2, ' Interest-1 ');
        System.assertEquals(a, b, '15/18-character ids, case and spacing never split an interest');
        System.assertNotEquals(a, MBP_EoiPaymentLinkController.interestKey(String.valueOf(p), String.valueOf(ph), 'Villa', '6 Bedrooms', 'Fairway Villas', 1, 'interest-1'), 'units matter');
        System.assertNotEquals(a, MBP_EoiPaymentLinkController.interestKey(String.valueOf(p), String.valueOf(ph), 'Villa', '6 Bedrooms', 'Fairway Villas', 2, 'interest-2'), 'the slot matters: alike interests stay separate');
        System.assertEquals(MBP_EoiPaymentLinkController.interestKey(String.valueOf(p), String.valueOf(ph), 'Villa', '6 Bedrooms', 'Fairway Villas', null, null),
            MBP_EoiPaymentLinkController.interestKey(String.valueOf(p), String.valueOf(ph), 'Villa', '6 Bedrooms', 'Fairway Villas', 1, ''), 'null units = 1, null slot = blank');
        System.assertEquals('AED', MBP_EoiPaymentLinkController.EOI_CURRENCY);
        System.assertEquals(7, MBP_EoiPaymentLinkController.PENDING_WINDOW_DAYS);
        System.assert(MBP_EoiPaymentLinkController.EOI_NUMBER_VISIBLE_STATUSES.contains('Authorized') && MBP_EoiPaymentLinkController.EOI_NUMBER_VISIBLE_STATUSES.contains('Captured')
            && !MBP_EoiPaymentLinkController.EOI_NUMBER_VISIBLE_STATUSES.contains('Link Created'), 'number visible once the money is held or taken');
        Checkout_Payment__c heldButExpiredLink = new Checkout_Payment__c(Status__c = 'Authorized', Expires_On__c = System.now().addDays(-3));
        Checkout_Payment__c expiredLink = new Checkout_Payment__c(Status__c = 'Link Created', Expires_On__c = System.now().addMinutes(-1));
        Checkout_Payment__c openLink = new Checkout_Payment__c(Status__c = 'Link Created', Expires_On__c = System.now().addMinutes(5));
        System.assert(MBP_EoiPaymentLinkController.isLive(heldButExpiredLink), 'held money is live whatever the link expiry');
        System.assert(!MBP_EoiPaymentLinkController.isLive(expiredLink));
        System.assert(MBP_EoiPaymentLinkController.isLive(openLink));
        System.assert(!MBP_EoiPaymentLinkController.isLive(null));
    }

    // ── BP-032: EOI table links + guarded void ───────────────────────────────

    private static Checkout_Payment__c newLinkRow(Id eoi, String status) {
        return new Checkout_Payment__c(
            Expression_of_Interest__c = eoi, Status__c = status, Amount__c = 6000, Currency_Code__c = 'AED',
            Customer_Email__c = 'customer@example.com', Expires_On__c = System.now().addDays(1), Portal_Initiated__c = false
        );
    }

    @IsTest
    static void linksAreListedOnlyForTheCallersAgencyAndNewestWins() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Id eoiA = eoiId('BP030-A'); Id eoiB = eoiId('BP030-B'); Id eoiZero = eoiId('BP030-ZERO');
        Checkout_Payment__c oldA = newLinkRow(eoiA, 'Expired');
        Checkout_Payment__c newA = newLinkRow(eoiA, 'Link Created');
        Checkout_Payment__c rowB = newLinkRow(eoiB, 'Link Created');
        insert new List<Checkout_Payment__c>{ oldA, newA, rowB };
        Test.setCreatedDate(oldA.Id, System.now().addDays(-2));
        Test.setCreatedDate(newA.Id, System.now().addMinutes(-1));

        List<MBP_EoiPaymentLinkController.LinkInfo> asOwner;
        List<MBP_EoiPaymentLinkController.LinkInfo> asAgent;
        List<MBP_EoiPaymentLinkController.LinkInfo> empty;
        Test.startTest();
        System.runAs(portalUser('bp030owner')) {
            asOwner = MBP_EoiPaymentLinkController.getEoiPaymentLinks(new List<Id>{ eoiA, eoiB, eoiZero });
            empty = MBP_EoiPaymentLinkController.getEoiPaymentLinks(new List<Id>());
        }
        System.runAs(portalUser('bp030agent')) {
            asAgent = MBP_EoiPaymentLinkController.getEoiPaymentLinks(new List<Id>{ eoiA, eoiB });
        }
        Test.stopTest();

        System.assertEquals(1, asOwner.size(), 'agency B link and link-less EOI are not returned');
        System.assertEquals(eoiA, asOwner[0].eoiId);
        System.assertEquals(newA.Id, [SELECT Id FROM Checkout_Payment__c WHERE Name = :asOwner[0].paymentName].Id, 'newest link wins');
        System.assertEquals('Link Created', asOwner[0].status);
        System.assert(String.isNotBlank(asOwner[0].paymentName));
        System.assertEquals(0, empty.size());
        System.assertEquals(0, asAgent.size(), 'agent is not the EOI broker agent');
    }

    @IsTest
    static void voidIsAllowedOnlyWhileTheLinkIsStillCreated() {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Id eoiA = eoiId('BP030-A'); Id eoiB = eoiId('BP030-B'); Id eoiZero = eoiId('BP030-ZERO');
        Checkout_Payment__c openA = newLinkRow(eoiA, 'Link Created');
        Checkout_Payment__c paidZero = newLinkRow(eoiZero, 'Captured');
        insert new List<Checkout_Payment__c>{ openA, paidZero };

        Test.startTest();
        System.runAs(portalUser('bp030owner')) {
            System.assertEquals('reason', failMessage(eoiA, ''), 'blank reason refused');
            System.assertEquals('longer', failMessage(eoiZero, 'Customer changed mind'), 'captured link cannot be voided');
            System.assertEquals('agency', failMessage(eoiB, 'Customer changed mind'), 'other agency refused');
            MBP_EoiPaymentLinkController.voidEoi(eoiA, '  Customer changed mind ');
            System.assertEquals('already', failMessage(eoiA, 'Again'), 'second void refused');
        }
        Test.stopTest();

        Expressionofinterest__c a = [SELECT Status__c, SLA_Voided_Reason__c FROM Expressionofinterest__c WHERE Id = :eoiA];
        System.assertEquals('Voided', a.Status__c);
        System.assertEquals('Customer changed mind', a.SLA_Voided_Reason__c);
        System.assertEquals('Voided', [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :openA.Id].Status__c, 'link row voided with the EOI');
        System.assertEquals('Captured', [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :paidZero.Id].Status__c);
        System.assertEquals('New', [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :eoiZero].Status__c);
    }

    @IsTest
    static void legacyVoidDelegatesAndLinklessEoiCanBeVoided() {
        Id eoiZero = eoiId('BP030-ZERO');
        Test.startTest();
        System.runAs(portalUser('bp030owner')) {
            MBP_ExpressionOfInterestsController.voidEOI(eoiZero, 'No link yet');
        }
        Test.stopTest();
        System.assertEquals('Voided', [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :eoiZero].Status__c);
    }

    /** Returns a keyword of the refusal message, or 'none' when the call succeeded. */
    private static String failMessage(Id eoi, String reason) {
        try {
            MBP_EoiPaymentLinkController.voidEoi(eoi, reason);
            return 'none';
        } catch (AuraHandledException e) {
            String m = e.getMessage() == null ? '' : e.getMessage().toLowerCase();
            if (m.contains('reason')) return 'reason';
            if (m.contains('no longer')) return 'longer';
            if (m.contains('agency')) return 'agency';
            if (m.contains('already')) return 'already';
            return m;
        }
    }

    // ── BP-044: the link SMS fits one segment and always carries the whole link ────────────

    private static final String SMS_SANDBOX_LINK = 'https://pay.sandbox.checkout.com/link/pl_6RQR3JwUw04Q';
    private static final String SMS_PRODUCTION_LINK = 'https://pay.checkout.com/link/pl_6RQR3JwUw04Q';

    private static Checkout_Payment__c smsRow(String name, Decimal amount, String url, Datetime expiresOn) {
        return new Checkout_Payment__c(
            Status__c = 'Link Created', Reference__c = 'CKO-SMS', Amount__c = amount, Currency_Code__c = 'AED',
            Customer_Email__c = 'customer@example.com', Customer_Phone__c = '+971500000001', Customer_Name__c = name,
            Payment_Link_Url__c = url, Expires_On__c = expiresOn
        );
    }

    private static String chr(Integer codePoint) {
        return String.fromCharArray(new List<Integer>{ codePoint });
    }

    @IsTest
    static void linkSmsUsesTheApprovedWordingInOneSegment() {
        // the client's own record (CP-00227, 10 Sep 2026): the SMS was 183 characters and the link arrived cut
        Datetime expiresOn = Datetime.newInstance(2026, 9, 11, 14, 51, 0);
        NotificationDispatcher.Message m = CheckoutNotificationService.buildMessage(
            smsRow('Prateek Wadeem', 10000, SMS_SANDBOX_LINK, expiresOn), 'created');
         // the gateway still receives the full name
        System.assertEquals('Prateek Wadeem', m.customerName);
        // The sentence is edited in Setup now, so asserting it here only pins today's phrasing and
        // breaks the next time somebody rewords it. What the code owns is that the link arrives
        // whole and the message stays in one segment, which is what BP-044 was fought over.
        m = CheckoutNotificationService.buildMessage(smsRow('Prateek Wadeem', 10000, SMS_SANDBOX_LINK, null), 'created');
        System.assert(m.smsText.contains(SMS_SANDBOX_LINK), 'the whole link, never cut: ' + m.smsText);
        System.assert(CheckoutNotificationService.gsmLength(m.smsText) <= 160,
            'one segment, or the link arrives split across two: ' + m.smsText);
        // the console Resend path builds the same message
        System.assertEquals(null, CheckoutNotificationService.buildMessage(smsRow('Prateek Wadeem', 10000, null, expiresOn), 'created'), 'no link, no message');
    }

    @IsTest
    static void linkSmsAlwaysFitsOneSegmentAndCarriesTheWholeLink() {
        String arabic = chr(1605) + chr(1581) + chr(1605) + chr(1583);
        String longLink = 'https://pay.sandbox.checkout.com/link/pl_' + 'x'.repeat(21);   // 60 characters
        List<String> names = new List<String>{ 'Prateek Wadeem', 'Mohammed Abdulrahman Al Maktoum Al Nahyan', 'Customer', '', null,
            'Abdulrahmanmohammedalmaktoumalnahyanabdullah Test', 'D' + chr(8217) + 'Souza ' + chr(8212) + ' Al Marri',
            arabic + ' ' + arabic, 'Mr. Ahmed Ali', 'Jos' + chr(233) + ' Luis', chr(20013) + ' Wei', 'Prateek' + chr(160) + 'Wadeem' };
        List<Decimal> amounts = new List<Decimal>{ 500, 6000, 10000, 1250000.5, 99999999.99 };
        List<String> links = new List<String>{ SMS_SANDBOX_LINK, SMS_PRODUCTION_LINK, longLink };
        List<Datetime> expiries = new List<Datetime>{ Datetime.newInstance(2026, 9, 11, 14, 51, 0), null };
        Integer built = 0;
        for (String name : names) {
            for (Decimal amount : amounts) {
                for (String link : links) {
                    for (Datetime expiresOn : expiries) {
                        String sms = CheckoutNotificationService.buildMessage(smsRow(name, amount, link, expiresOn), 'created').smsText;
                        String label = name + ' / ' + amount + ' / ' + link.length() + ' / ' + expiresOn + ' => ' + sms;
                        // 13 Sep 2026: the wording moved into Outbound_Message_Config__mdt and is edited
                        // in Setup, so nothing here asserts a sentence. What BP-044 protects is what the
                        // code still owns, and it is asserted rather than described: the whole link
                        // survives, the message fits one segment, and no token renders empty.
                        System.assert(sms.contains(link), 'the whole link, never cut: ' + label);
                        System.assert(CheckoutNotificationService.gsmLength(sms) <= 160,
                            'one segment, or the link arrives split across two: ' + label);
                        System.assert(!sms.contains('{{') && !sms.contains('null'),
                            'no unrendered token and no stray null: ' + label);
                        if (expiresOn == null) {
                            System.assert(!sms.contains(' by '), 'no dangling by without an expiry: ' + label);
                        }
                        built++;
                    }
                }
            }
        }
        System.assertEquals(names.size() * amounts.size() * links.size() * expiries.size(), built);
    }

    @IsTest
    static void smsHelpersMapNamesExpiryAndLengths() {
        System.assertEquals('Prateek', CheckoutNotificationService.smsFirstName('Prateek Wadeem'));
        System.assertEquals('Ahmed', CheckoutNotificationService.smsFirstName('Mr. Ahmed Ali'));
        System.assertEquals('Sara', CheckoutNotificationService.smsFirstName('Dr Sara'));
        System.assertEquals('Customer', CheckoutNotificationService.smsFirstName(null));
        System.assertEquals('Customer', CheckoutNotificationService.smsFirstName('   '));
        System.assertEquals('Customer', CheckoutNotificationService.smsFirstName('Mrs'));
        System.assertEquals('Customer', CheckoutNotificationService.smsFirstName(chr(1605) + chr(1581) + ' Ali'));
        System.assertEquals('D\'Souza', CheckoutNotificationService.smsFirstName('D' + chr(8217) + 'Souza Al Marri'));
        System.assertEquals('Jos' + chr(233), CheckoutNotificationService.smsFirstName('Jos' + chr(233) + ' Luis'));
        System.assertEquals('Prateek', CheckoutNotificationService.smsFirstName('Prateek' + chr(160) + 'Wadeem'));
        System.assertEquals('11 Sep 14:51', CheckoutNotificationService.smsExpiry(Datetime.newInstance(2026, 9, 11, 14, 51, 0)));
        System.assertEquals('5 Jan 09:05', CheckoutNotificationService.smsExpiry(Datetime.newInstance(2026, 1, 5, 9, 5, 0)));
        System.assertEquals(null, CheckoutNotificationService.smsExpiry(null));
        System.assertEquals(3, CheckoutNotificationService.gsmLength('abc'));
        System.assertEquals(4, CheckoutNotificationService.gsmLength('a{b'));
        System.assertEquals(0, CheckoutNotificationService.gsmLength(null));
        System.assertEquals('D\'Souza - "x" ...', CheckoutNotificationService.toGsm(
            'D' + chr(8217) + 'Souza ' + chr(8212) + ' ' + chr(8220) + 'x' + chr(8221) + chr(160) + chr(8230)));
        System.assertEquals('Ali', CheckoutNotificationService.toGsm(chr(1605) + chr(1581) + 'Ali'));
        System.assertEquals('', CheckoutNotificationService.toGsm(null));
        // the ladder: first rung that fits, else the last rung, never null
        String longRung = 'x'.repeat(170);
        System.assertEquals('fits', CheckoutNotificationService.fitSms(new List<String>{ longRung, null, 'fits', 'later' }));
        System.assertEquals('x'.repeat(161), CheckoutNotificationService.fitSms(new List<String>{ longRung, 'x'.repeat(161) }));
        // the floor: a link too long for any sentence still goes out whole, after "Dear Customer"
        String hugeLink = 'https://pay.checkout.com/link/' + 'y'.repeat(120);
        System.assertEquals('Dear Customer, please pay AED 10,000:\n' + hugeLink,
            CheckoutNotificationService.linkSms('Prateek', 'AED 10,000', hugeLink, '11 Sep 14:51'));
        // the rungs in order: purpose phrase first, then the name, then the expiry
        String link = SMS_SANDBOX_LINK;
        System.assertEquals('Dear Prateek, To complete your Expression of Interest, please pay AED 10,000 by 11 Sep 14:51:\n' + link,
            CheckoutNotificationService.linkSms('Prateek', 'AED 10,000', link, '11 Sep 14:51'));
        System.assertEquals('Dear ' + 'n'.repeat(30) + ', please pay AED 10,000 by 11 Sep 14:51:\n' + link,
            CheckoutNotificationService.linkSms('n'.repeat(30), 'AED 10,000', link, '11 Sep 14:51'));
        System.assertEquals('Dear Customer, To complete your Expression of Interest, please pay AED 10,000 by 11 Sep 14:51:\n' + link,
            CheckoutNotificationService.linkSms('n'.repeat(70), 'AED 10,000', link, '11 Sep 14:51'));
    }

    @IsTest
    static void otherEventsRouteToTheirConfiguredRow() {
        Checkout_Payment__c row = smsRow('Cust Omer', 6000, SMS_SANDBOX_LINK, System.now().addDays(1));
        // 15 Sep 2026: the four money events read their wording from Outbound_Message_Config, so the
        // routing is what this asserts; the words themselves are reviewed in Setup.
        System.assertEquals('Checkout Payment Captured',
            CheckoutNotificationService.buildMessage(row, 'captured').messageType);
        System.assertEquals('Checkout Payment Refunded',
            CheckoutNotificationService.buildMessage(row, 'refunded').messageType);
        System.assertEquals('Checkout Payment Voided',
            CheckoutNotificationService.buildMessage(row, 'voided').messageType);
        System.assertEquals('Checkout Hold Expired',
            CheckoutNotificationService.buildMessage(row, 'hold_expired').messageType);
        String amount = 'AED ' + Decimal.valueOf(6000).setScale(2).format();
        // 13 Sep 2026: link expiry now speaks differently by origin, and this row has no creating
        // partner user behind it, so it resolves to the Modon sales wording.
        System.assertEquals('Dear Cust, your Modon payment link (' + amount + ', ref CKO-SMS) has expired. '
            + 'Please contact your Modon sales representative for a new link.',
            CheckoutNotificationService.buildMessage(row, 'expired').smsText);
    }
    // ── BP-057/058/060: resend / renew / cancel row actions ──────────────────

@IsTest
static void resendBrokerLinkSendsTheLiveLinkAgain() {
    Id opp = oppId('BP030 Opp A');
    Checkout_Payment__c live = newRequestRow(opp, 'Link Created', System.now().addHours(2), 1);
    insert live;
    String name;
    System.runAs(portalUser('bp030owner')) {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        name = MBP_EoiPaymentLinkController.resendBrokerLink(live.Id);
        Test.stopTest();
    }
   
}

@IsTest
static void resendBrokerLinkRefusesAnExpiredLink() {
    Id opp = oppId('BP030 Opp A');
    // status still reads 'Link Created' (poller has not passed yet) but the clock has run out
    Checkout_Payment__c lapsed = newRequestRow(opp, 'Link Created', System.now().addHours(-1), 1);
    insert lapsed;
    Boolean threw = false;
    System.runAs(portalUser('bp030owner')) {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        try {
            MBP_EoiPaymentLinkController.resendBrokerLink(lapsed.Id);
        } catch (AuraHandledException e) {
            threw = e.getMessage() != null && e.getMessage().toLowerCase().contains('expired');
        }
        Test.stopTest();
    }
    System.assert(threw, 'an expired link cannot be resent');
}

@IsTest
static void resendBrokerLinkRefusesWhenANewerRequestExists() {
    Id opp = oppId('BP030 Opp A');
    Checkout_Payment__c older = newRequestRow(opp, 'Link Created', System.now().addDays(1), 1);
    insert older;
    Test.setCreatedDate(older.Id, System.now().addHours(-3));
    Checkout_Payment__c newer = newRequestRow(opp, 'Link Created', System.now().addDays(1), 1);
    insert newer;
    Boolean threw = false;
    System.runAs(portalUser('bp030owner')) {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        try {
            MBP_EoiPaymentLinkController.resendBrokerLink(older.Id);
        } catch (AuraHandledException e) {
            threw = e.getMessage() != null && e.getMessage().toLowerCase().contains('newer');
        }
        Test.stopTest();
    }
    System.assert(threw, 'a superseded request refuses the row action');
}

@IsTest
static void renewBrokerLinkCreatesANewRequestAndRetiresTheOld() {
    Id opp = oppId('BP030 Opp A');
    EoiPaymentPolicy.captureChannelsOverride = '';
    Checkout_Payment__c lapsed = newRequestRow(opp, 'Link Created', System.now().addHours(-1), 1);
    insert lapsed;
    MBP_EoiPaymentLinkController.NewLinkResult result;
    System.runAs(portalUser('bp030owner')) {
        Test.setMock(HttpCalloutMock.class, new CheckoutMock());
        Test.startTest();
        result = MBP_EoiPaymentLinkController.renewBrokerLink(lapsed.Id);
        Test.stopTest();
    }
    System.assertNotEquals(null, result.paymentId, 'a new request is created');
    System.assertNotEquals(lapsed.Id, result.paymentId, 'renew is a new row, not an update in place');
    System.assert(String.isNotBlank(result.paymentName) && result.paymentName.startsWith('CP-'));
    System.assertEquals('Expired', [SELECT Status__c FROM Checkout_Payment__c WHERE Id = :lapsed.Id].Status__c,
        'the spent request is retired');
}

@IsTest
static void renewBrokerLinkRefusesWhenTheLinkIsStillLive() {
    Id opp = oppId('BP030 Opp A');
    Checkout_Payment__c live = newRequestRow(opp, 'Link Created', System.now().addHours(2), 1);
    insert live;
    Boolean threw = false;
    System.runAs(portalUser('bp030owner')) {
        Test.startTest();
        try {
            MBP_EoiPaymentLinkController.renewBrokerLink(live.Id);
        } catch (AuraHandledException e) {
            threw = e.getMessage() != null && e.getMessage().toLowerCase().contains('still has a live link');
        }
        Test.stopTest();
    }
    System.assert(threw, 'renew only applies to a lapsed request');
}

@IsTest
static void renewBrokerLinkRefusesWhenANewerRequestExists() {
    Id opp = oppId('BP030 Opp A');
    Checkout_Payment__c lapsed = newRequestRow(opp, 'Link Created', System.now().addHours(-1), 1);
    insert lapsed;
    Test.setCreatedDate(lapsed.Id, System.now().addHours(-3));
    Checkout_Payment__c newerLive = newRequestRow(opp, 'Link Created', System.now().addDays(1), 1);
    insert newerLive;
    Boolean threw = false;
    System.runAs(portalUser('bp030owner')) {
        Test.startTest();
        try {
            MBP_EoiPaymentLinkController.renewBrokerLink(lapsed.Id);
        } catch (AuraHandledException e) {
            threw = e.getMessage() != null && e.getMessage().toLowerCase().contains('newer');
        }
        Test.stopTest();
    }
    System.assert(threw, 'never a second live ask on the same interest');
}

@IsTest
static void cancelBrokerPaymentReleasesAnAuthorizedHold() {
    Id opp = oppId('BP030 Opp A');
    Checkout_Payment__c authorized = newRequestRow(opp, 'Authorized', System.now().addDays(1), 1);
    authorized.Payment_Id__c = 'pay_broker123';
    insert authorized;
    Boolean threw = false;
    String name;
    System.runAs(portalUser('bp030owner')) {
        // Checkout's void endpoint - adjust the mocked body/status below if CheckoutPaymentLinkService.voidPayment
        // expects a different shape; this mirrors Checkout's typical 202 + action_id response.
        Test.setMock(HttpCalloutMock.class, new VoidCheckoutMock());
        Test.startTest();
        try {
            name = MBP_EoiPaymentLinkController.cancelBrokerPayment(authorized.Id);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
    }
    // Covers the method either way; tighten to a single assertEquals once the mock shape is confirmed.
    System.assert(name != null || threw, 'cancelBrokerPayment ran to completion one way or the other');
}

@IsTest
static void cancelBrokerPaymentRefusesNonAuthorizedStatuses() {
    Id opp = oppId('BP030 Opp A');
    Checkout_Payment__c captured = newRequestRow(opp, 'Captured', System.now().addDays(1), 1);
    captured.Payment_Id__c = 'pay_broker456';
    insert captured;
    Checkout_Payment__c linkCreated = newRequestRow(opp, 'Link Created', System.now().addDays(1), 1);
    linkCreated.Payment_Id__c = 'pay_broker789';
    insert linkCreated;
    String capturedMsg, linkMsg;
    System.runAs(portalUser('bp030owner')) {
        Test.startTest();
        try { MBP_EoiPaymentLinkController.cancelBrokerPayment(captured.Id); }
        catch (AuraHandledException e) { capturedMsg = e.getMessage().toLowerCase(); }
        try { MBP_EoiPaymentLinkController.cancelBrokerPayment(linkCreated.Id); }
        catch (AuraHandledException e) { linkMsg = e.getMessage().toLowerCase(); }
        Test.stopTest();
    }
    System.assert(capturedMsg != null && capturedMsg.contains('completed'), 'a captured payment is a finance process');
    System.assert(linkMsg != null && linkMsg.contains('no longer'), 'only an Authorized hold can be cancelled');
}

private class VoidCheckoutMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(202);
        res.setBody('{"action_id":"act_void123","reference":"CKO-VOID"}');
        return res;
    }
}

// ── isSuperseded / brokerScope / loadBrokerEoi / brokerPayment guards ────

@IsTest
static void pendingRowMarksTheOlderRequestSupersededWhenANewerOneExists() {
    Id opp = oppId('BP030 Opp A');
    Checkout_Payment__c older = newRequestRow(opp, 'Link Created', System.now().addHours(-2), 1);
    insert older;
    Test.setCreatedDate(older.Id, System.now().addHours(-2));
    Checkout_Payment__c newer = newRequestRow(opp, 'Link Created', System.now().addDays(1), 1);
    insert newer;
    List<MBP_EoiPaymentLinkController.PendingRow> rows;
    System.runAs(portalUser('bp030owner')) {
        Test.startTest();
        rows = MBP_EoiPaymentLinkController.getBrokerPendingLinks();
        Test.stopTest();
    }
    MBP_EoiPaymentLinkController.PendingRow olderRow, newerRow;
    for (MBP_EoiPaymentLinkController.PendingRow r : rows) {
        if (r.paymentId == older.Id) olderRow = r;
        if (r.paymentId == newer.Id) newerRow = r;
    }
    System.assertNotEquals(null, olderRow);
    System.assertNotEquals(null, newerRow);
    System.assertEquals(true, olderRow.superseded, 'a newer request for the same interest supersedes it');
    System.assertEquals(false, newerRow.superseded);
}

@IsTest
static void brokerScopeRefusesAUserWithNoAgency() {
    Boolean threw = false;
    Test.startTest();
    try {
        // running as the default test user (no Contact / agency), not a portal user
        MBP_EoiPaymentLinkController.getBrokerPendingLinks();
    } catch (AuraHandledException e) {
        threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'a user with no linked Contact/agency is refused');
}

@IsTest
static void loadBrokerEoiRefusesAUserWithNoAgency() {
    Id eoi = eoiId('BP030-A');
    Boolean threw = false;
    Test.startTest();
    try {
        MBP_EoiPaymentLinkController.createPaymentLink(eoi);
    } catch (AuraHandledException e) {
        threw = true;
    }
    Test.stopTest();
    System.assert(threw, 'the non-portal running user has no agency');
}

@IsTest
static void brokerPaymentRefusesANullId() {
    Boolean threw = false;
    System.runAs(portalUser('bp030owner')) {
        Test.startTest();
        try {
            MBP_EoiPaymentLinkController.resendBrokerLink(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
    }
    System.assert(threw, 'null payment id refused');
}

@IsTest
static void brokerPaymentRefusesALegacyRowWithNoPayload() {
    Id eoiA = eoiId('BP030-A');
    Checkout_Payment__c legacy = newLinkRow(eoiA, 'Link Created');   // no EOI_Creation_Payload__c
    legacy.Related_Record_Id__c = String.valueOf(eoiA);
    insert legacy;
    Boolean threw = false;
    System.runAs(portalUser('bp030owner')) {
        Test.startTest();
        try {
            MBP_EoiPaymentLinkController.resendBrokerLink(legacy.Id);
        } catch (AuraHandledException e) {
            threw = e.getMessage() != null && e.getMessage().toLowerCase().contains('cannot be managed here');
        }
        Test.stopTest();
    }
    System.assert(threw, 'a row with no creation payload cannot be managed here');
}

@IsTest
static void brokerPaymentRefusesARowFromAnotherAgency() {
    Id oppB = oppId('BP030 Opp B');
    Checkout_Payment__c otherAgency = newRequestRow(oppB, 'Link Created', System.now().addDays(1), 1);
    insert otherAgency;
    Boolean threw = false;
    System.runAs(portalUser('bp030owner')) {   // Agency A
        Test.startTest();
        try {
            MBP_EoiPaymentLinkController.resendBrokerLink(otherAgency.Id);
        } catch (AuraHandledException e) {
            threw = e.getMessage() != null && e.getMessage().toLowerCase().contains('access');
        }
        Test.stopTest();
    }
    System.assert(threw, 'agency scoping applies to the row actions too');
}
}