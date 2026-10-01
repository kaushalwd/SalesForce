/**
 * CheckoutEoiMaterializerBrokerTest - Aurelix IT, 10 Sep 2026 (BP-041)
 * The one additive block the Broker Portal adds to MODON's shared CheckoutEoiMaterializer: an EOI raised from a
 * broker's Opportunity carries BrokerAgency__c, BrokerAgent__c and the 48 h allocation timer; console rows stay
 * untouched. Driven through the real trigger path (Link Created -> Authorized on a payload row), exactly as the
 * poller / console do it. MODON's own suites (EoiCheckoutPaymentControllerTest, CheckoutPaymentPollerTest,
 * EoiReceiptBuilderTest) remain the proof that everything else is unchanged.
 */
@IsTest
private class CheckoutEoiMaterializerBrokerTest {

    /** Absorbs the WhatsApp / SMS callouts the EOI creation cascade makes from its queueables. */
    private class QuietMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{}');
            return res;
        }
    }

    @TestSetup
    static void seed() {
        Account agency = new Account(Name = 'BP041 Agency');
        List<RecordType> rts = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1];
        if (!rts.isEmpty()) agency.RecordTypeId = rts[0].Id;
        insert agency;
        Contact broker = new Contact(LastName = 'Broker', AccountId = agency.Id, Email = 'broker@example.com', Broker_Type__c = 'Owner');
        insert broker;

        Account customer = new Account(Name = 'BP041 Customer', Phone = '+971500000009');
        insert customer;
        Contact cust = new Contact(AccountId = customer.Id, FirstName = 'Cust', LastName = 'Omer', Email = 'cust@example.com', MobilePhone = '+971500000002');
        insert cust;

        Opportunity brokerOpp = new Opportunity(Name = 'BP041 Broker Opp', StageName = 'Discussion In Progress', CloseDate = Date.today().addDays(10), AccountId = customer.Id);
        putIfFieldExists(brokerOpp, 'ContactId', cust.Id);
        putIfFieldExists(brokerOpp, 'PrimaryContact__c', cust.Id);
        putIfFieldExists(brokerOpp, 'BrokerAgency__c', agency.Id);
        putIfFieldExists(brokerOpp, 'BrokerAgent__c', broker.Id);
        Opportunity consoleOpp = new Opportunity(Name = 'BP041 Console Opp', StageName = 'Discussion In Progress', CloseDate = Date.today().addDays(10), AccountId = customer.Id);
        putIfFieldExists(consoleOpp, 'ContactId', cust.Id);
        insert new List<Opportunity>{ brokerOpp, consoleOpp };

        SObject project = Schema.getGlobalDescribe().get('Project__c').newSObject();
        project.put('Name', 'BP041 Project');
        insert project;
        SObject range = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        putIfFieldExists(range, 'Project__c', project.Id);
        putIfFieldExists(range, 'Amount__c', 6000);
        putIfFieldExists(range, 'Is_Active__c', true);
        putIfFieldExists(range, 'Unit_Type__c', 'Villa');
        putIfFieldExists(range, 'No_of_Bedrooms__c', '6 Bedrooms');
        putIfFieldExists(range, 'UnitTypologyMRE__c', 'Fairway Villas');
        putIfFieldExists(range, 'Applicable_for_Broker__c', true);
        insert range;
    }

    private static void putIfFieldExists(SObject rec, String f, Object v) {
        if (v != null && rec.getSObjectType().getDescribe().fields.getMap().containsKey(f.toLowerCase())) rec.put(f, v);
    }

    // an org automation appends a date suffix to Opportunity names, so match on the prefix
    private static Opportunity opp(String name) {
        String prefix = name + '%';
        return [SELECT Id, AccountId, ContactId, BrokerAgency__c, BrokerAgent__c FROM Opportunity WHERE Name LIKE :prefix LIMIT 1];
    }

    private static String payloadFor(Id oppId) {
        Id projectId = [SELECT Id FROM Project__c WHERE Name = 'BP041 Project' LIMIT 1].Id;
        Id rangeId = [SELECT Id FROM EOI_Range__c WHERE Project__c = :projectId LIMIT 1].Id;
        return JSON.serialize(new Map<String, Object>{
            'opportunityId' => String.valueOf(oppId), 'projectId' => String.valueOf(projectId), 'eoiRangeId' => String.valueOf(rangeId),
            'eoiAmount' => 6000, 'numberOfUnits' => 1, 'paymentType' => 'Online', 'remarks' => 'BP041',
            'unitType' => 'Villa', 'bedrooms' => '6 Bedrooms', 'unitTypology' => 'Fairway Villas', 'currencyCode' => 'AED',
            'brokerSlot' => 'interest-1'   // the broker portal's extra key: the rail must ignore it
        });
    }

    private static Checkout_Payment__c newHeldRow(Id oppId, String reference) {
        // Portal_Initiated = true keeps the insert quiet (no "link created" message); the update to Authorized is the path under test.
        return new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Link Created', Amount__c = 6000, Currency_Code__c = 'AED',
            Customer_Name__c = 'Cust Omer', Customer_Email__c = 'cust@example.com', Customer_Phone__c = '+971500000002',
            Related_Record_Id__c = String.valueOf(oppId), EOI_Creation_Payload__c = payloadFor(oppId),
            Expires_On__c = System.now().addDays(1), Portal_Initiated__c = true, Capture_Mode__c = 'Authorize'
        );
    }

    private static Datetime parseTimer(String value) {
        // 'yyyy-MM-dd'T'HH:mm:ss'Z'' as MBP_ExpressionOfInterestsController.updateBrokerAllocationTimer writes it
        return Datetime.valueOfGmt(value.replace('T', ' ').replace('Z', ''));
    }

    @IsTest
    static void authorizedBrokerPaymentRaisesAnEoiWithAgencyAgentAndTimer() {
        Opportunity brokerOpp = opp('BP041 Broker Opp');
        Opportunity consoleOpp = opp('BP041 Console Opp');
        Checkout_Payment__c brokerRow = newHeldRow(brokerOpp.Id, 'CKO-BP041-BROKER');
        Checkout_Payment__c consoleRow = newHeldRow(consoleOpp.Id, 'CKO-BP041-CONSOLE');
        insert new List<Checkout_Payment__c>{ brokerRow, consoleRow };
        CheckoutEoiMaterializer.allocationHoursOverride = 48;
        Test.setMock(HttpCalloutMock.class, new QuietMock());

        Test.startTest();
        brokerRow.Status__c = 'Authorized';
        consoleRow.Status__c = 'Authorized';
        update new List<Checkout_Payment__c>{ brokerRow, consoleRow };     // sync trigger path: materialize on the hold
        Test.stopTest();

        Map<Id, Checkout_Payment__c> rows = new Map<Id, Checkout_Payment__c>([
            SELECT Id, Expression_of_Interest__c, Receipt__c FROM Checkout_Payment__c WHERE Id IN :new List<Id>{ brokerRow.Id, consoleRow.Id }
        ]);
        System.assertNotEquals(null, rows.get(brokerRow.Id).Expression_of_Interest__c, 'the hold raised the broker EOI');
        System.assertNotEquals(null, rows.get(consoleRow.Id).Expression_of_Interest__c, 'the hold raised the console EOI');
        System.assertEquals(null, rows.get(brokerRow.Id).Receipt__c, 'a hold is not money received: no receipt');

        Expressionofinterest__c brokerEoi = [
            SELECT Status__c, Skip_SLA__c, BrokerAgency__c, BrokerAgent__c, Account__c, Contact__c, Opportunity__c,
                   Broker_Allocation_Timer__c, Payment_Type__c, EOI_Amount_AED__c, Number_of_Units__c
            FROM Expressionofinterest__c WHERE Id = :rows.get(brokerRow.Id).Expression_of_Interest__c
        ];
        System.assertEquals('Payment Authorized', brokerEoi.Status__c);
        System.assertEquals(true, brokerEoi.Skip_SLA__c, 'held money is never chased');
        System.assertEquals(brokerOpp.BrokerAgency__c, brokerEoi.BrokerAgency__c, 'agency from the Opportunity');
        System.assertEquals(brokerOpp.BrokerAgent__c, brokerEoi.BrokerAgent__c, 'agent from the Opportunity');
        System.assertEquals(brokerOpp.AccountId, brokerEoi.Account__c);
        System.assertEquals(brokerOpp.ContactId, brokerEoi.Contact__c);
        System.assertEquals(brokerOpp.Id, brokerEoi.Opportunity__c);
        System.assertEquals('Online', brokerEoi.Payment_Type__c);
        System.assertEquals(6000, brokerEoi.EOI_Amount_AED__c);
        System.assert(Pattern.matches('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z', brokerEoi.Broker_Allocation_Timer__c),
            'timer in the exact updateBrokerAllocationTimer shape: ' + brokerEoi.Broker_Allocation_Timer__c);
        Long deltaMinutes = (parseTimer(brokerEoi.Broker_Allocation_Timer__c).getTime() - System.now().addHours(48).getTime()) / 60000;
        System.assert(Math.abs(deltaMinutes) <= 5, '48 h window from the hold, got delta ' + deltaMinutes + ' min');

        Expressionofinterest__c consoleEoi = [
            SELECT Status__c, Skip_SLA__c, BrokerAgency__c, BrokerAgent__c, Broker_Allocation_Timer__c
            FROM Expressionofinterest__c WHERE Id = :rows.get(consoleRow.Id).Expression_of_Interest__c
        ];
        System.assertEquals('Payment Authorized', consoleEoi.Status__c, 'console behaviour unchanged');
        System.assertEquals(true, consoleEoi.Skip_SLA__c);
        System.assertEquals(null, consoleEoi.BrokerAgency__c, 'no agency on a console Opportunity');
        System.assertEquals(null, consoleEoi.BrokerAgent__c);
        System.assertEquals(null, consoleEoi.Broker_Allocation_Timer__c, 'no timer on a console EOI');
    }

    @IsTest
    static void allocationTimerHonoursTheOverrideAndAlwaysFallsBackTo48Hours() {
        CheckoutEoiMaterializer.allocationHoursOverride = 10;
        String ten = CheckoutEoiMaterializer.brokerAllocationTimer();
        System.assert(Pattern.matches('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z', ten), ten);
        System.assert(Math.abs((parseTimer(ten).getTime() - System.now().addHours(10).getTime()) / 60000) <= 5, 'override honoured');

        CheckoutEoiMaterializer.allocationHoursOverride = -5;           // nonsense -> 48 h, never an exception
        String fallback = CheckoutEoiMaterializer.brokerAllocationTimer();
        System.assert(Math.abs((parseTimer(fallback).getTime() - System.now().addHours(48).getTime()) / 60000) <= 5, 'fallback 48 h');

        CheckoutEoiMaterializer.allocationHoursOverride = null;         // label path (MBP_BrokerAllocationHours, 48 in the org)
        String fromLabel = CheckoutEoiMaterializer.brokerAllocationTimer();
        System.assert(String.isNotBlank(fromLabel) && Pattern.matches('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z', fromLabel), fromLabel);
        System.assert(parseTimer(fromLabel) > System.now(), 'always in the future');
    }

    // ── BP-049: one transaction raises every waiting EOI, up to the cap ──────

    /**
     * The change the client is waiting for. Two payments authorized together used to become one EOI
     * per five minute poller cycle; runOne now raises both in a single pass. Portal_Initiated keeps
     * the trigger's sync path out of the way so this exercises the poller path only.
     */
    @IsTest
    static void oneRunRaisesEveryWaitingEoiInsteadOfOne() {
        Opportunity first  = opp('BP041 Broker Opp');
        Opportunity second = opp('BP041 Console Opp');
        Checkout_Payment__c rowA = newHeldRow(first.Id,  'CKO-BP048-A');
        Checkout_Payment__c rowB = newHeldRow(second.Id, 'CKO-BP048-B');
        rowA.Status__c = 'Authorized';
        rowB.Status__c = 'Authorized';
        insert new List<Checkout_Payment__c>{ rowA, rowB };     // inserted already Authorized: no sync materialise
        Test.setMock(HttpCalloutMock.class, new QuietMock());

        Test.startTest();
        Boolean moreLeft = CheckoutMaterializeQueueable.runOne(7);
        Test.stopTest();

        Map<Id, Checkout_Payment__c> after = new Map<Id, Checkout_Payment__c>([
            SELECT Id, Expression_of_Interest__c FROM Checkout_Payment__c WHERE Id IN :new List<Id>{ rowA.Id, rowB.Id }
        ]);
        System.assertNotEquals(null, after.get(rowA.Id).Expression_of_Interest__c, 'first EOI raised');
        System.assertNotEquals(null, after.get(rowB.Id).Expression_of_Interest__c, 'second EOI raised in the SAME pass');
        System.assertNotEquals(after.get(rowA.Id).Expression_of_Interest__c, after.get(rowB.Id).Expression_of_Interest__c,
            'two payments, two separate EOIs');
        System.assertEquals(false, moreLeft, 'nothing is left over, so no chain is requested');
    }

    /**
     * The cap exists because each EOI generates a form and Apex allows 120 seconds of callout time
     * per transaction. Over the cap, the remainder must be reported back so the next pass takes it.
     */
    @IsTest
    static void theBatchIsCappedAndTheRemainderIsReportedBack() {
        Opportunity first  = opp('BP041 Broker Opp');
        Opportunity second = opp('BP041 Console Opp');
        Checkout_Payment__c rowA = newHeldRow(first.Id,  'CKO-BP048-CAP-A');
        Checkout_Payment__c rowB = newHeldRow(second.Id, 'CKO-BP048-CAP-B');
        rowA.Status__c = 'Authorized';
        rowB.Status__c = 'Authorized';
        insert new List<Checkout_Payment__c>{ rowA, rowB };
        Test.setMock(HttpCalloutMock.class, new QuietMock());
        CheckoutMaterializeQueueable.eoisPerRunOverride = 1;      // force the cap to bite

        Test.startTest();
        Boolean moreLeft = CheckoutMaterializeQueueable.runOne(7);
        Test.stopTest();

        System.assertEquals(true, moreLeft, 'the row beyond the cap must be reported so the next pass takes it');
        Integer raised = 0;
        for (Checkout_Payment__c cp : [SELECT Expression_of_Interest__c FROM Checkout_Payment__c
                                       WHERE Id IN :new List<Id>{ rowA.Id, rowB.Id }]) {
            if (cp.Expression_of_Interest__c != null) raised++;
        }
        System.assertEquals(1, raised, 'exactly the cap was raised, oldest first');
    }

    /** The cap can never fall below one, or a run would raise nothing and loop forever. */
    @IsTest
    static void theCapNeverDropsBelowOne() {
        System.assertEquals(3, CheckoutMaterializeQueueable.MAX_EOIS_PER_RUN, 'default stays at three');
        Opportunity only = opp('BP041 Broker Opp');
        Checkout_Payment__c row = newHeldRow(only.Id, 'CKO-BP048-FLOOR');
        row.Status__c = 'Authorized';
        insert row;
        Test.setMock(HttpCalloutMock.class, new QuietMock());
        CheckoutMaterializeQueueable.eoisPerRunOverride = 0;      // nonsense value

        Test.startTest();
        CheckoutMaterializeQueueable.runOne(7);
        Test.stopTest();

        System.assertNotEquals(null,
            [SELECT Expression_of_Interest__c FROM Checkout_Payment__c WHERE Id = :row.Id].Expression_of_Interest__c,
            'a zero cap must still raise one, never zero');
    }

    /** Nothing waiting means no work and no chain. */
    @IsTest
    static void anEmptyQueueAsksForNothing() {
        Test.setMock(HttpCalloutMock.class, new QuietMock());
        Test.startTest();
        System.assertEquals(false, CheckoutMaterializeQueueable.runOne(7), 'no eligible rows, no chain');
        Test.stopTest();
    }

    /** A row with no creation payload is not ours to finish and must never hold up the queue. */
    @IsTest
    static void aRowWithoutAPayloadIsSkipped() {
        Opportunity only = opp('BP041 Broker Opp');
        Checkout_Payment__c row = newHeldRow(only.Id, 'CKO-BP048-NOPAYLOAD');
        row.EOI_Creation_Payload__c = null;
        row.Status__c = 'Authorized';
        insert row;
        Test.setMock(HttpCalloutMock.class, new QuietMock());

        Test.startTest();
        System.assertEquals(false, CheckoutMaterializeQueueable.runOne(7), 'a payload-less row is not a candidate');
        Test.stopTest();

        System.assertEquals(null,
            [SELECT Expression_of_Interest__c FROM Checkout_Payment__c WHERE Id = :row.Id].Expression_of_Interest__c,
            'and no EOI is invented for it');
    }
}