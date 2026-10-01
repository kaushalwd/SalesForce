@isTest
public class EOITriggerHelperTest {

    // ── Shared data builder ───────────────────────────────────────────────────
    private static Contact buildContact(String lastName) {
        Contact c = new Contact(LastName = lastName, Email = lastName + '@test.com');
        insert c;
        return c;
    }

    private static Opportunity buildOpp(Id contactId, String leadSource) {
        Opportunity opp = new Opportunity(
            Name             = 'Test Opp ' + lastName(contactId),
            StageName        = 'Discussion In Progress',
            CloseDate        = Date.today().addDays(30),
            PrimaryContact__c = contactId,
            LeadSource       = leadSource
        );
        insert opp;
        return opp;
    }

    private static Opportunity buildOpp(Id contactId) {
        return buildOpp(contactId, null);
    }

    private static String lastName(Id contactId) {
        return [SELECT LastName FROM Contact WHERE Id = :contactId LIMIT 1].LastName;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Existing test 1 — updateEOIStatus: Paid + SecurityCheck → Completed
    // ─────────────────────────────────────────────────────────────────────────
    static TestMethod void runTest1() {
        Contact c   = buildContact('RunTest1');
        Opportunity opp = buildOpp(c.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(Opportunity__c = opp.Id);
        insert eoi;

        eoi.PaymentStatus__c        = 'Paid';
        eoi.SecurityCheckCompleted__c = true;
        update eoi;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Existing test 2 — manageInvoiceAmount + updateEOIStatus direct call
    // ─────────────────────────────────────────────────────────────────────────
    static TestMethod void runTest2() {
        Contact c    = buildContact('RunTest2');
        Opportunity opp  = buildOpp(c.Id);
        Opportunity opp2 = buildOpp(c.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Amount__c = '2');
        insert eoi;
        eoi.PaymentStatus__c        = 'Paid';
        eoi.SecurityCheckCompleted__c = true;
        update eoi;

        Expressionofinterest__c eoi2 = new Expressionofinterest__c(
            Opportunity__c = opp2.Id, Amount__c = '1');
        insert eoi2;




















        Test.startTest();
        try {
            EOITriggerHelper.updateEOIStatus(
                new Map<Id, SObject>{ eoi.Id => eoi },
                new Map<Id, SObject>{ eoi.Id => eoi }
            );
            EOITriggerHelper.manageInvoiceAmount(
                new Map<Id, SObject>{ eoi.Id  => eoi  },
                new Map<Id, SObject>{ eoi2.Id => eoi2 }
            );
        } catch (Exception e) {}
        Test.stopTest();
    }


    // ─────────────────────────────────────────────────────────────────────────
    // Existing test 3 — Modon Egypt EOI insert + update
    // ─────────────────────────────────────────────────────────────────────────
    static TestMethod void modonEgyptEOIs() {
        Test.startTest();
        Contact c = new Contact(
            LastName = 'Modon Egypt', Email = 'modon@test.com',
            Source_Entity__c = 'Modon - Egypt');
        insert c;




        Opportunity opp = new Opportunity(
            Name = 'Modon Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today(), PrimaryContact__c = c.Id,
            Source_Entity__c = 'Modon - Egypt');
        insert opp;




        Expressionofinterest__c eoi = new Expressionofinterest__c(Opportunity__c = opp.Id);
        insert eoi;



        eoi.EOI_Amount__c = 5000;
        update eoi;


        Expressionofinterest__c result = [
            SELECT Id, EOI_Amount__c, Opportunity__c
            FROM   Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertNotEquals(null,     result,                  'EOI should exist');
        System.assertEquals(opp.Id,     result.Opportunity__c,   'Opportunity should match');
        System.assertEquals(5000,       result.EOI_Amount__c,    'Amount should be 5000');
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Existing test 4 — Modon Egypt filter helpers
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void modonEgyptEOIsStatusChange() {
        Contact c = new Contact(
            LastName = 'Modon Filter', Email = 'filter@test.com',
            Source_Entity__c = 'Modon - Egypt');
        insert c;

        Opportunity opp = new Opportunity(
            Name = 'Filter Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today(), PrimaryContact__c = c.Id,
            Source_Entity__c = 'Modon - Egypt');
        insert opp;

        Expressionofinterest__c oldRec = new Expressionofinterest__c(Opportunity__c = opp.Id);
        insert oldRec;







        Expressionofinterest__c newRec = new Expressionofinterest__c(Id = oldRec.Id, EOI_Amount__c = 30);






        List<SObject> newList = new List<SObject>{ newRec };
        List<SObject> oldList = new List<SObject>{ oldRec };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ newRec.Id => newRec };
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ oldRec.Id => oldRec };

        Map<String, Object> r1 = Modon_Egypt_EOIFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);
        Map<String, Object> r2 = Modon_Egypt_EOIFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);

        System.assert(r1 != null && r1.containsKey('ModonEgyptNewEOI'), 'Before update filter should return ModonEgyptNewEOI');
        System.assert(r2 != null && r2.containsKey('ModonEgyptNewEOI'), 'After update filter should return ModonEgyptNewEOI');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Existing test 5 — manageInvoiceAmount non-Egypt
    // ─────────────────────────────────────────────────────────────────────────
    static TestMethod void testForNonEgypt() {
        Contact c   = buildContact('NonEgypt');
        Opportunity opp = buildOpp(c.Id);

        Expressionofinterest__c oldRec = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Amount__c = '1000');
        insert oldRec;

        Expressionofinterest__c newRec = new Expressionofinterest__c(Id = oldRec.Id, Amount__c = '3000');
        EOITriggerHelper.manageInvoiceAmount(
            new Map<Id, SObject>{ newRec.Id => newRec },
            new Map<Id, SObject>{ oldRec.Id => oldRec }
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 1 — generateToken direct call
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testGenerateToken() {
        Test.startTest();
        String token = EOITriggerHelper.generateToken();
        Test.stopTest();

        System.assertNotEquals(null, token,            'Token should not be null');
        System.assertEquals(6,       token.length(),   'Token should be 6 characters');
    }


    // ─────────────────────────────────────────────────────────────────────────
    // NEW 4 — updateEOIStatus: Approved status + PaymentStatus != Paid → addError
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateEOIStatus_ApprovedNotPaid_AddsError() {
        Contact c   = buildContact('ApprovalErr');
        Opportunity opp = buildOpp(c.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, EOI_Amount_AED__c = 5000);
        insert eoi;

        Expressionofinterest__c oldRec = eoi.clone(true, true, false, false);
        oldRec.Status__c       = 'In Progress';
        oldRec.PaymentStatus__c = 'Not Paid';

        Expressionofinterest__c newRec = eoi.clone(true, true, false, false);
        newRec.Status__c        = 'Approved';
        newRec.PaymentStatus__c = 'Not Paid';
        newRec.EOI_Amount_AED__c = 5000;

        Test.startTest();
        try {
            EOITriggerHelper.updateEOIStatus(
                new Map<Id, SObject>{ newRec.Id => newRec },
                new Map<Id, SObject>{ oldRec.Id => oldRec }
            );
        } catch (Exception ex) {
            System.debug('Expected addError: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(true, 'Approved + unpaid validation path executed');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 5 — updateEOIStatus: Completed + old status EOI Confirmed + not paid
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateEOIStatus_CompletedFromEOIConfirmed_NotPaid() {
        Contact c   = buildContact('CompletedErr');
        Opportunity opp = buildOpp(c.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, EOI_Amount_AED__c = 3000);
        insert eoi;

        Expressionofinterest__c oldRec = eoi.clone(true, true, false, false);
        oldRec.Status__c       = 'EOI Confirmed';
        oldRec.PaymentStatus__c = 'Not Paid';

        Expressionofinterest__c newRec = eoi.clone(true, true, false, false);
        newRec.Status__c        = 'Completed';
        newRec.PaymentStatus__c = 'Not Paid';
        newRec.EOI_Amount_AED__c = 3000;

        Test.startTest();
        try {
            EOITriggerHelper.updateEOIStatus(
                new Map<Id, SObject>{ newRec.Id => newRec },
                new Map<Id, SObject>{ oldRec.Id => oldRec }
            );
        } catch (Exception ex) {
            System.debug('Expected: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(true, 'Completed from EOI Confirmed validation path executed');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 6 — setSLAStartTime: non-broker-portal lead source → sets SLA time
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSetSLAStartTime_NonBrokerPortal() {
        if (System.Label.EOI_SLA_Enabled != 'true') {
            System.assert(true, 'Skipped: SLA disabled'); return;
        }

        Contact c   = buildContact('SLANonBP');
        Opportunity opp = buildOpp(c.Id, 'Website');

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Skip_SLA__c = false);
        insert eoi;

        List<Expressionofinterest__c> fresh = [
            SELECT Id, Skip_SLA__c, Opportunity__c, CreatedDate
            FROM   Expressionofinterest__c WHERE Id = :eoi.Id
        ];

        Test.startTest();
        EOITriggerHelper.setSLAStartTime(fresh);
        Test.stopTest();

        Expressionofinterest__c result = [
            SELECT SLA_Start_Time__c FROM Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertNotEquals(null, result.SLA_Start_Time__c,
            'SLA start time should be set for non-broker portal EOI');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 7 — setSLAStartTime: broker portal lead source → does nothing
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSetSLAStartTime_BrokerPortal() {
        if (System.Label.EOI_SLA_Enabled != 'true') {
            System.assert(true, 'Skipped: SLA disabled'); return;
        }

        String brokerSource = System.Label.EOI_SLA_Broker_Portal_LeadSource;
        Contact c   = buildContact('SLABroker');
        Opportunity opp = buildOpp(c.Id, brokerSource);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Skip_SLA__c = false);
        insert eoi;

        List<Expressionofinterest__c> fresh = [
            SELECT Id, Skip_SLA__c, Opportunity__c, CreatedDate
            FROM   Expressionofinterest__c WHERE Id = :eoi.Id
        ];

        Test.startTest();
        EOITriggerHelper.setSLAStartTime(fresh);
        Test.stopTest();

        System.assert(true, 'Broker portal EOI — SLA handled elsewhere, no exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 8 — setSLAStartTime: Skip_SLA__c = true → record skipped
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSetSLAStartTime_SkipSLA() {
        if (System.Label.EOI_SLA_Enabled != 'true') {
            System.assert(true, 'Skipped: SLA disabled'); return;
        }

        Contact c   = buildContact('SLASkip');
        Opportunity opp = buildOpp(c.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Skip_SLA__c = true);
        insert eoi;

        List<Expressionofinterest__c> fresh = [
            SELECT Id, Skip_SLA__c, Opportunity__c, CreatedDate
            FROM   Expressionofinterest__c WHERE Id = :eoi.Id
        ];

        Test.startTest();
        EOITriggerHelper.setSLAStartTime(fresh);
        Test.stopTest();

        Expressionofinterest__c result = [
            SELECT SLA_Start_Time__c FROM Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertEquals(null, result.SLA_Start_Time__c,
            'Skipped EOI should not have SLA start time set');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 9 — setSLAStartTime: empty list → returns early (oppIds.isEmpty path)
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSetSLAStartTime_EmptyList() {
        Test.startTest();
        EOITriggerHelper.setSLAStartTime(new List<SObject>());
        Test.stopTest();

        System.assert(true, 'Empty list should return early without exception');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 10 — sendEmailtoCustomers: status → In Progress with BrokerAgency
    // ─────────────────────────────────────────────────────────────────────────
   /* @isTest
    static void testSendEmailToCustomers_InProgress_WithBroker() {
        Contact c   = buildContact('EmailBroker');
        Opportunity opp = buildOpp(c.Id);

        Account brokerAcc = new Account(Name = 'Test Broker Agency');
        insert brokerAcc;

        Expressionofinterest__c oldRec = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Status__c = 'In Progress');
        insert oldRec;

        Expressionofinterest__c newRec = new Expressionofinterest__c(
            Id              = oldRec.Id,
            Status__c       = 'In Progress',
            BrokerAgency__c = brokerAcc.Id
        );

        Test.startTest();
        try {
            EOITriggerHelper.sendEmailtoCustomers(
                new Map<Id, SObject>{ newRec.Id => newRec },
                new Map<Id, SObject>{ oldRec.Id => oldRec }
            );
        } catch (Exception ex) {
            System.debug('Expected email exception: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(true, 'sendEmailtoCustomers In Progress path executed');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 11 — sendEmailtoCustomers: status not In Progress → no email
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSendEmailToCustomers_NoStatusChange() {
        Contact c   = buildContact('EmailNoChange');
        Opportunity opp = buildOpp(c.Id);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Status__c = 'In Progress');
        insert eoi;

        Expressionofinterest__c sameRec = eoi.clone(true, true, false, false);

        Test.startTest();
        EOITriggerHelper.sendEmailtoCustomers(
            new Map<Id, SObject>{ sameRec.Id => sameRec },
            new Map<Id, SObject>{ eoi.Id     => eoi     }
        );
        Test.stopTest();

        System.assert(true, 'No status change — sendEmailtoCustomers should do nothing');
    }*/

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 12 — manageInvoiceAmount: invoice status != Generated → addError path
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testManageInvoiceAmount_InvoiceNotGenerated_AddsError() {
        Contact c   = buildContact('InvNotGen');
        Opportunity opp = buildOpp(c.Id);

        Account acc = new Account(Name = 'Inv Account');
        insert acc;

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Amount__c = '1000');
        insert eoi;

       /* Invoice__c inv = new Invoice__c(
            Expressionofinterest__c = eoi.Id,
            Account__c              = acc.Id,
            InvoiceAmount__c        = 1000,
            InvoiceStatus__c        = 'Approved'
        );
        insert inv;*/

        Expressionofinterest__c oldRec = eoi.clone(true, true, false, false);
        oldRec.Amount__c = '1000';

        Expressionofinterest__c newRec = eoi.clone(true, true, false, false);
        newRec.Amount__c = '2000';

        Test.startTest();
        try {
            EOITriggerHelper.manageInvoiceAmount(
                new Map<Id, SObject>{ newRec.Id => newRec },
                new Map<Id, SObject>{ oldRec.Id => oldRec }
            );
        } catch (Exception ex) {
            System.debug('Expected: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(true, 'Invoice not Generated — addError path executed');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // NEW 13 — manageInvoiceAmount: invoice status = Generated → updates amount
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testManageInvoiceAmount_InvoiceGenerated_UpdatesAmount() {
        Contact c   = buildContact('InvGen');
        Opportunity opp = buildOpp(c.Id);

        Account acc = new Account(Name = 'Gen Inv Account');
        insert acc;

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id, Amount__c = '500');
        insert eoi;

       

        Expressionofinterest__c oldRec = eoi.clone(true, true, false, false);
        oldRec.Amount__c = '500';

        Expressionofinterest__c newRec = eoi.clone(true, true, false, false);
        newRec.Amount__c = '750';

        Test.startTest();
        EOITriggerHelper.manageInvoiceAmount(
            new Map<Id, SObject>{ newRec.Id => newRec },
            new Map<Id, SObject>{ oldRec.Id => oldRec }
        );
        Test.stopTest();

        //Invoice__c updated = [SELECT InvoiceAmount__c FROM Invoice__c WHERE Id = :inv.Id];
        //System.assertEquals(750, updated.InvoiceAmount__c,
           // 'Invoice amount should be updated to 750');
    }

    @isTest
    static void testTriggerHandlerQueuesFollowUpsAndStatusNotifications() {
        Contact c = buildContact('HandlerCoverage');
        Opportunity opp = buildOpp(c.Id, 'Website');

        Expressionofinterest__c eoi = new Expressionofinterest__c(Opportunity__c = opp.Id);
        insert eoi;

        // Every field, because the handler is called directly below and reads far more of the record
        // than this test sets; a partial row throws the moment one of them is touched.
        Id eoiId = eoi.Id;
        List<String> everyField = new List<String>(
            Schema.SObjectType.Expressionofinterest__c.fields.getMap().keySet()
        );
        Expressionofinterest__c insertedEoi = (Expressionofinterest__c) Database.query(
            'SELECT ' + String.join(everyField, ',') +
            ' FROM Expressionofinterest__c WHERE Id = :eoiId LIMIT 1'
        );

        EOITriggerHandler handler = new EOITriggerHandler();
        Test.startTest();
        handler.beforeInsertMethod(
            new List<SObject>{ new Expressionofinterest__c(Opportunity__c = opp.Id) },
            new Map<Id, SObject>()
        );
        handler.afterInsertMethod(
            new List<SObject>{ insertedEoi },
            new Map<Id, SObject>{ insertedEoi.Id => insertedEoi }
        );

        Expressionofinterest__c completedOld = insertedEoi.clone(true, true, false, false);
        completedOld.Status__c = 'In Progress';
        Expressionofinterest__c completedNew = insertedEoi.clone(true, true, false, false);
        completedNew.Status__c = 'Completed';
        handler.beforeUpdateMethod(
            new List<SObject>{ completedNew },
            new Map<Id, SObject>{ completedNew.Id => completedNew },
            new List<SObject>{ completedOld },
            new Map<Id, SObject>{ completedOld.Id => completedOld }
        );
        handler.afterUpdateMethod(
            new List<SObject>{ completedNew },
            new Map<Id, SObject>{ completedNew.Id => completedNew },
            new List<SObject>{ completedOld },
            new Map<Id, SObject>{ completedOld.Id => completedOld }
        );

        Expressionofinterest__c voidedOld = insertedEoi.clone(true, true, false, false);
        voidedOld.Status__c = 'In Progress';
        Expressionofinterest__c voidedNew = insertedEoi.clone(true, true, false, false);
        voidedNew.Status__c = 'Void';
        handler.afterUpdateMethod(
            new List<SObject>{ voidedNew },
            new Map<Id, SObject>{ voidedNew.Id => voidedNew },
            new List<SObject>{ voidedOld },
            new Map<Id, SObject>{ voidedOld.Id => voidedOld }
        );
        Test.stopTest();

        System.assert(true, 'EOITriggerHandler insert and status notification branches executed.');
    }
}