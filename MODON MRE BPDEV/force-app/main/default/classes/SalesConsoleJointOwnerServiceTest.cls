/**
 * SalesConsoleJointOwnerService.
 *
 * Version  Author      Date         Detail
 * 2.4      Aurelix Dev 29 Sep 2026  Service 2.4: a rep with no access to another user's person still finds,
 *                                   checks and is offered them in createPerson's chooser.
 * 2.3      Aurelix Dev 29 Sep 2026  Service 2.3: a Nationality or Resident Status off the list is refused
 *                                   with nothing written; another case is written as the list spells it.
 * 2.2      Aurelix Dev 28 Sep 2026  Service 2.2. The buyer's match before a new person: a document or an email
 *                                   match stops createPerson with nothing written and the matches returned,
 *                                   one already on the booking is marked, addOwner refuses, create anyway is
 *                                   refused in MODON's words while ALLOW_NEW_CUSTOMER_DESPITE_MATCH is off and
 *                                   creates while it is on, and no match still creates. The joint owner's
 *                                   manual KYC route: partyProblem, the checklist for someone not yet added,
 *                                   the evaluation and MODON's submission on their Account, the approved
 *                                   outcome and trail, and the generation refusal.
 * 2.1      Aurelix Dev 22 Sep 2026  MODON's joint owner KYC check (JointOwnerTriggerHelper 2.0):
 *                                   the person card carries its result, an add without KYC gets
 *                                   MODON's message, a KYC link goes to a person not yet on the
 *                                   booking, and createPerson creates without adding. MODON's
 *                                   check is off in tests unless bypassKYCCheck is set to false.
 * 1.x      Aurelix Dev 21 Sep 2026  openBasket() now skips an order whose SPA has gone out, as
 *                                   openOrderWithNoOwners() already did. Six SeeAllData failures
 *                                   came from baskets the service would never accept.
 * 1.0      Aurelix IT  20 Aug 2026  Initial. MSC-080.
 * 1.2      Aurelix IT  20 Aug 2026  MSC-083. Compliance state per party: the reason,
 *                                   the tally's bound, and the one assertion that keeps
 *                                   this class and SalesConsoleComplianceService from
 *                                   disagreeing about whether somebody has already been
 *                                   sent - which they did, because 1.1 read one of the
 *                                   three ways of knowing.
 * 1.1      Aurelix IT  20 Aug 2026  MSC-082. Identity verification per party: the state
 *                                   on every PartyDTO, the guard that stops
 *                                   sendVerification being pointed at an account that is
 *                                   not on this booking, and the rule that matters most -
 *                                   updateOwner fills a blank contact field and NEVER
 *                                   overwrites one that is already there.
 *
 * Two halves, for two different reasons - the same split
 * SalesConsoleComplianceServiceTest records.
 *
 * THE REFUSALS THAT NEED NO BOOKING are built from scratch. A state the panel has to
 * render - no booking, a company account, a booking with no confirmed unit - is proved on
 * data this class creates and controls.
 *
 * EVERYTHING ELSE IS SeeAllData. A SalesOrder__c cannot be built synthetically in this
 * org: it wants an escrow account, a virtual account, a payment plan with installment
 * templates and an Oracle callout, and Custom Metadata a test cannot insert decides half
 * of it. More to the point, the thing under test is how our rules sit alongside MODON's
 * trigger, its before-save Flow and the real status ladders - none of which a synthetic
 * order exercises. So these run against real bookings. The transaction rolls back either
 * way, and every one of them says plainly what data it could not find rather than passing
 * on an empty list.
 */
@isTest
private class SalesConsoleJointOwnerServiceTest {

    private static final String EGYPT = 'Modon - Egypt';
    private static final Set<String> DEAD = new Set<String>{
        'Cancelled', 'System cancelled', 'Voided',
        'Cancelled SR', 'Property Transfer Cancelled - SR'
    };
    /* 2.0 - the service's STATUS_SPA_OUT, mirrored the way DEAD already is. Without
       it the helpers hand back an order checkWritable refuses - which is exactly what
       happened when SO-15474 reached Completed and became the org's newest
       clean-looking order, and 18 tests failed on data none of them was about. */
    /* 1.x - the service compares these with equalsIgnoreCase (inSet) and its own DEAD_ORDERS
       set is written in lower case. Matching them here with Set.contains, which is
       case-sensitive, is how a status that differs only in case passed for clean and was then
       refused by the service. One matcher, the service's rule. */
    private static Boolean inAny(Set<String> values, String candidate) {
        if (String.isBlank(candidate) || values == null) {
            return false;
        }
        for (String v : values) {
            if (v != null && v.equalsIgnoreCase(candidate)) {
                return true;
            }
        }
        return false;
    }

    private static final Set<String> SPA_OUT = new Set<String>{
        'SPA Sent to customer', 'SPA Signed (Customer)', 'SPA Signed (Modon)',
        'SPA Delivered', 'SPA Validated', 'Completed'
    };

    // ══════════════════════════════════════════════════════════════════════
    // helpers
    // ══════════════════════════════════════════════════════════════════════

    private static Id personRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount'
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /** A co-owner candidate. allowSave because the org's duplicate rules are live here. */
    private static Account newPerson(String tag, String residency) {
        Account a = new Account(
            FirstName    = 'JOTest',
            LastName     = 'Candidate' + tag,
            RecordTypeId = personRecordTypeId()
        );
        if (String.isNotBlank(residency)) {
            a.UAE_Resident_Status__pc = residency;
        }
        /* Short on purpose. Modon's AccountTrigger copies EIDNumber__pc into an
           EmiratesId field with a tighter limit, and anything over 18 characters is
           refused with "data changed by trigger ... data value too large". A real
           formatted Emirates ID is exactly 18, so production fits; a test tag need not
           come close. */
        a.EIDNumber__pc = 'JOT' + tag;
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        Database.SaveResult sr = Database.insert(a, o);
        System.assert(sr.isSuccess(),
            'The test could not create a co-owner candidate: '
            + (sr.getErrors().isEmpty() ? '(no error given)' : sr.getErrors()[0].getMessage()));
        return [
            SELECT Id, Name, PersonContactId, IsPersonAccount, Is_Merged__c,
                   UAE_Resident_Status__pc
            FROM Account WHERE Id = :a.Id
        ];
    }

    private static Opportunity opportunityFor(Account a) {
        Opportunity o = new Opportunity(
            Name       = 'Joint Owner Test Booking',
            AccountId  = a.Id,
            StageName  = 'Qualification',
            CloseDate  = System.today().addDays(30)
        );
        insert o;
        return o;
    }

    /** A live booking whose SPA has not started and which carries no owners yet. */
    private static SalesOrder__c openOrderWithNoOwners() {
        for (SalesOrder__c so : [
            SELECT Id, Name, Opportunity__c, Status__c, SPAStatus__c, Source_Entity__c,
                   Unit__c, Unit__r.Name
            FROM SalesOrder__c
            WHERE Opportunity__r.Account.IsPersonAccount = true
            AND SPA_Send_Date_for_Signature__c = null
            AND (SPAStatus__c = null OR SPAStatus__c = 'SPA Not Generated')
            AND Id NOT IN (SELECT SalesOrder__c FROM JointOwner__c WHERE SalesOrder__c != null)
            ORDER BY CreatedDate DESC
            LIMIT 60
        ]) {
            if (!inAny(DEAD, so.Status__c)
                    && !inAny(SPA_OUT, so.Status__c)
                    && so.Source_Entity__c != EGYPT) {
                return so;
            }
        }
        return null;
    }

    /** A live booking sitting at a named point on the SPA ladder. */
    private static SalesOrder__c orderAtSpaStatus(String spaStatus) {
        for (SalesOrder__c so : [
            SELECT Id, Name, Opportunity__c, Status__c, SPAStatus__c, Source_Entity__c,
                   Unit__c, Unit__r.Name
            FROM SalesOrder__c
            WHERE Opportunity__r.Account.IsPersonAccount = true
            AND SPAStatus__c = :spaStatus
            ORDER BY CreatedDate DESC
            LIMIT 40
        ]) {
            if (!inAny(DEAD, so.Status__c) && so.Source_Entity__c != EGYPT) {
                return so;
            }
        }
        return null;
    }

    /**
     * A live booking at a named rung of the SPA ladder.
     *
     * A real one when this org has one. It does not: all four orders at SPA Generated or
     * Pending for Validation here are Cancelled or Voided, so they never reach the SPA
     * guard - the dead-order guard refuses them first. Rather than leave the rung
     * untested, a real open order is stamped and the transaction rolls it back.
     */
    private static SalesOrder__c orderAtSpaStatusOrStamped(String spaStatus) {
        SalesOrder__c real = orderAtSpaStatus(spaStatus);
        if (real != null) {
            return real;
        }
        SalesOrder__c open = openOrderWithNoOwners();
        if (open == null) {
            return null;
        }
        update new SalesOrder__c(Id = open.Id, SPAStatus__c = spaStatus);
        open.SPAStatus__c = spaStatus;
        return open;
    }

    private static SalesConsoleJointOwnerService.AddOwnerInput req(
        SalesOrder__c so, Id accountId, Decimal share
    ) {
        SalesConsoleJointOwnerService.AddOwnerInput r =
            new SalesConsoleJointOwnerService.AddOwnerInput();
        r.opportunityId       = so.Opportunity__c;
        r.salesOrderId        = so.Id;
        r.targetOrderIds      = new List<Id>{ so.Id };
        r.accountId           = accountId;
        r.share               = share;
        r.relationshipType    = 'Joint Owner P-P';
        r.relationshipSubType = 'Spouse';
        return r;
    }

    /** The message of whatever was thrown, or null when nothing was. */
    private static String refusalFrom(SalesConsoleJointOwnerService.AddOwnerInput r) {
        try {
            SalesConsoleJointOwnerService.addOwner(r);
            return null;
        } catch (Exception e) {
            return e.getMessage();
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // the refusals that need no booking
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Nothing selected is a state, not a failure. getOwners has to render something for
     * every caller - the same contract getChecklist and getComplianceState keep.
     */
    @isTest
    static void testNothingSelectedIsAState() {
        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(null, null);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'An answer must always come back.');
        System.assertEquals(false, dto.available, 'Nothing was selected, so nothing can be shown.');
        System.assertNotEquals(null, dto.blockedReason, 'The rep must be told why.');
    }

    /**
     * A corporate booking is Sales Operations' path. The console must not offer a second
     * one, and must say so rather than fail silently.
     */
    /**
     * 2.0 - MSC-180. THE OLD REFUSAL, INVERTED ON PURPOSE. Until 2.0 this test held
     * the corporate gate shut; the gate is open now, so a corporate booking is blocked
     * only by what blocks anyone - here, having no confirmed unit - and the reason
     * must say THAT, not "company". buyerIsCompany still rides out even when blocked,
     * because the pane loads the company's verification tracks off it.
     */
    @isTest
    static void testCompanyBuyerIsBlockedOnlyByTheUnit() {
        Account co = new Account(Name = 'Joint Owner Test Co');
        insert co;
        Opportunity o = opportunityFor(co);

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(o.Id, null);
        Test.stopTest();

        System.assertEquals(false, dto.available, 'There is no unit to own yet.');
        System.assert(
            dto.blockedReason != null && dto.blockedReason.containsIgnoreCase('unit'),
            'A corporate booking is refused for its missing unit, never for being '
            + 'corporate. Got: ' + dto.blockedReason
        );
        System.assertEquals(true, dto.buyerIsCompany,
            'The pane reads buyerIsCompany to keep the company tracks loading.');
    }

    /**
     * The whole design rests on writing against a Sales Order - it is what every
     * downstream reader traverses, and it is the only parent under which MODON's own
     * 100% rule fires. So a booking with no confirmed unit has nowhere to put an owner.
     */
    @isTest
    static void testBookingWithNoConfirmedUnitIsRefused() {
        Account buyer = newPerson('NOUNIT', 'Resident');
        Opportunity o = opportunityFor(buyer);

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(o.Id, null);
        Test.stopTest();

        System.assertEquals(false, dto.available, 'There is no unit to own.');
        System.assert(
            dto.blockedReason != null && dto.blockedReason.containsIgnoreCase('unit'),
            'The reason must name the missing unit. Got: ' + dto.blockedReason
        );
    }

    /** addOwner refuses the same booking getOwners refuses, and by throwing, not by null. */
    @isTest
    static void testAddOwnerRefusesABookingWithNoUnit() {
        Account buyer = newPerson('NOUNIT2', 'Resident');
        Opportunity o = opportunityFor(buyer);
        SalesConsoleJointOwnerService.AddOwnerInput r =
            new SalesConsoleJointOwnerService.AddOwnerInput();
        r.opportunityId = o.Id;
        r.share = 30;
        r.relationshipType = 'Joint Owner P-P';
        r.relationshipSubType = 'Spouse';

        Test.startTest();
        String msg = refusalFrom(r);
        Test.stopTest();

        System.assertNotEquals(null, msg, 'A booking with no unit must be refused.');
    }

    /** A blank document searches for nobody rather than returning everybody. */
    @isTest
    static void testFindPersonNeedsADocument() {
        Test.startTest();
        List<SalesConsoleJointOwnerService.PersonDTO> none =
            SalesConsoleJointOwnerService.findPerson(null, '   ');
        Test.stopTest();
        System.assertEquals(0, none.size(), 'A blank document must match nobody.');
    }

    /**
     * Search before create, and this is the search.
     *
     * It is the whole defence against a second record for someone the org already knows,
     * and the reason findPerson delegates to SalesConsoleLeadController rather than
     * carrying its own copy of the query.
     */
    @isTest
    static void testFindPersonFindsSomeoneAlreadyOnFile() {
        Account existing = newPerson('SEARCH', 'Resident');

        Test.startTest();
        List<SalesConsoleJointOwnerService.PersonDTO> found =
            SalesConsoleJointOwnerService.findPerson(null, 'JOTSEARCH');
        Test.stopTest();

        System.assertEquals(1, found.size(), 'The document must find the person holding it.');
        System.assertEquals(existing.Id, found[0].accountId, 'And it must be the right person.');
        System.assertEquals(null, found[0].blockedReason,
            'A clean person-account match has nothing blocking it. Got: ' + found[0].blockedReason);
    }

    // ══════════════════════════════════════════════════════════════════════
    // behaviour, against real bookings
    // ══════════════════════════════════════════════════════════════════════

    /** The picture the panel renders, on a booking that actually exists. */
    @isTest(SeeAllData=true)
    static void testOwnersDescribeARealBooking() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null,
            'No open Sales Order on a person-account opportunity in this org - the picture '
            + 'cannot be proved without one.');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        System.assertEquals(true, dto.available,
            'A live booking must be describable. Blocked: ' + dto.blockedReason);
        System.assert(!dto.parties.isEmpty(), 'The primary owner is always a party.');
        System.assertEquals(true, dto.parties[0].isPrimary,
            'The buyer comes first - a party model, not a joint-owner bolt-on.');
        System.assertEquals(so.Id, dto.focusedSalesOrderId,
            'The order asked for is a live order of this booking, so it must be the focus.');
        System.assert(!dto.units.isEmpty(), 'A booking with a confirmed unit lists it.');
        System.assert(!dto.relationshipTypes.isEmpty(),
            'The choices come from the field, so the field must have yielded some.');
        System.assertEquals(100, dto.primaryShare,
            'With no joint owners the buyer holds all of it.');
        System.assertEquals(6, dto.slotsRemaining, 'And all six slots are free.');
    }

    /**
     * The row we write, field by field.
     *
     * Opportunity__c is the one that matters: it must arrive populated WITHOUT this
     * class setting it, because the before-save Flow Joint_Owner_Before_Created_Updated
     * stamps it from the Sales Order. If that assertion ever fails, either the Flow was
     * switched off or someone added a second author for the field.
     */
    @isTest(SeeAllData=true)
    static void testAddOwnerWritesTheExactRow() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners to write onto.');
        Account person = newPerson('WRITE', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));
        Test.stopTest();

        List<JointOwner__c> rows = [
            SELECT Id, JointOwnerAccount__c, SalesOrder__c, Opportunity__c,
                   OwnershipPercentage__c, RelationshipType__c, RelationshipSubType__c
            FROM JointOwner__c
            WHERE SalesOrder__c = :so.Id AND JointOwnerAccount__c = :person.Id
        ];
        System.assertEquals(1, rows.size(), 'Exactly one row, on the unit asked for.');
        JointOwner__c jo = rows[0];
        System.assertEquals(person.Id, jo.JointOwnerAccount__c, 'The co-owner.');
        System.assertEquals(so.Id, jo.SalesOrder__c, 'The unit.');
        System.assertEquals(30, jo.OwnershipPercentage__c, 'Their Ownership %.');
        System.assertEquals('Joint Owner P-P', jo.RelationshipType__c, 'The Relationship Type.');
        System.assertEquals('Spouse', jo.RelationshipSubType__c, 'And its sub-type.');
        System.assertEquals(so.Opportunity__c, jo.Opportunity__c,
            'The before-save Flow stamps Opportunity__c from the Sales Order. This class '
            + 'never sets it, and if it arrives blank the Flow is not running.');

        /* THE DOWNSTREAM PROOF, and the most important assertion in this class.
           JO1__c and JO1_Ownership__c are Modon's JointOwnerTriggerHelper.updateJO
           output - we never write them. If they are populated, their trigger ran on our
           row, which is what makes the SPA recipients, the portal, the letters and eight
           batch jobs see this co-owner. A row we wrote that leaves these blank is a row
           nothing downstream will ever notice. */
        SalesOrder__c after = [
            SELECT JO1__c, JO1_Ownership__c FROM SalesOrder__c WHERE Id = :so.Id
        ];
        System.assertEquals(person.PersonContactId, after.JO1__c,
            'Modon\'s trigger must have flattened our row onto the Sales Order. If this '
            + 'is blank, nothing downstream of the console will see this joint owner.');
        System.assertEquals(30, after.JO1_Ownership__c, 'With their Ownership % alongside it.');

        System.assertEquals(70, dto.primaryShare, 'The primary owner now holds the remainder.');
        System.assertEquals(5, dto.slotsRemaining, 'One of six slots is taken.');
        System.assertEquals(1, dto.jointOwnerCount, 'And the booking has one joint owner.');
    }

    /** G8. A share outside 1-99 is not a share. */
    @isTest(SeeAllData=true)
    static void testShareRangeIsEnforced() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order to test against.');
        Account person = newPerson('RANGE', 'Resident');

        Test.startTest();
        System.assertNotEquals(null, refusalFrom(req(so, person.Id, 0)), 'Zero is not a valid Ownership %.');
        System.assertNotEquals(null, refusalFrom(req(so, person.Id, 100)), '100 leaves the buyer nothing.');
        System.assertNotEquals(null, refusalFrom(req(so, person.Id, null)), 'An Ownership % is required.');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id],
            'A refused share writes nothing.');
    }

    /**
     * G9, read from describe rather than from a list kept here.
     *
     * A copied list is a list that goes stale the day someone adds a relationship in
     * setup, and then the console refuses a value the org accepts.
     */
    @isTest(SeeAllData=true)
    static void testRelationshipIsValidatedAgainstDescribe() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order to test against.');
        Account person = newPerson('REL', 'Resident');

        SalesConsoleJointOwnerService.AddOwnerInput bad = req(so, person.Id, 30);
        bad.relationshipType = 'Cousin Twice Removed';
        SalesConsoleJointOwnerService.AddOwnerInput blank = req(so, person.Id, 30);
        blank.relationshipSubType = null;

        Test.startTest();
        System.assertNotEquals(null, refusalFrom(bad), 'A value the picklist does not hold is refused.');
        System.assertNotEquals(null, refusalFrom(blank), 'Both relationship fields are required.');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id],
            'Neither refusal wrote anything.');
    }

    /**
     * G7, and it is not a nicety.
     *
     * SendEnvelope refuses the WHOLE envelope - buyer included - when any joint owner's
     * resident status is blank, so a missing one takes the contract down for the entire
     * booking weeks later. It is caught at capture instead.
     */
    @isTest(SeeAllData=true)
    static void testResidentStatusIsRequired() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order to test against.');
        Account person = newPerson('NORES', null);

        Test.startTest();
        String msg = refusalFrom(req(so, person.Id, 30));
        Test.stopTest();

        System.assertNotEquals(null, msg, 'A blank resident status must be refused.');
        System.assert(msg.containsIgnoreCase('resident'),
            'And the message must say which detail is missing. Got: ' + msg);
        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id],
            'Nothing was written.');
    }

    /** G5. The same person is not a co-owner of the same unit twice. */
    @isTest(SeeAllData=true)
    static void testDuplicatePersonIsRefused() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('DUP', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));
        String msg = refusalFrom(req(so, person.Id, 20));
        Test.stopTest();

        System.assertNotEquals(null, msg, 'The second add must be refused.');
        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c
                                WHERE SalesOrder__c = :so.Id AND JointOwnerAccount__c = :person.Id],
            'And exactly one row survives.');
    }

    /** G5, the other branch. Nobody is their own joint owner. */
    @isTest(SeeAllData=true)
    static void testBuyerCannotBeTheirOwnJointOwner() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order to test against.');
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity WHERE Id = :so.Opportunity__c LIMIT 1];

        Test.startTest();
        String msg = refusalFrom(req(so, opp.AccountId, 30));
        Test.stopTest();

        System.assertNotEquals(null, msg, 'The primary owner cannot also be a joint owner.');
        System.assert(msg.containsIgnoreCase('primary owner'),
            'And the message must say so in Modon\'s own words (1.1). Got: ' + msg);
    }

    /**
     * G6, at MODON's own threshold.
     *
     * Their rule refuses at >= 100, not > 100, so 60 + 40 must be refused. Getting that
     * boundary wrong either lets a booking through that their trigger then rejects with a
     * message no rep can act on, or refuses a legitimate 99%.
     */
    @isTest(SeeAllData=true)
    static void testTotalOwnershipMustStayUnderAHundred() {
        /* 2.0 - REWRITTEN FOR MODON'S 24 AUG RULE, not for MSC-180. The original
           walked 60 + 39 to the brink of 100; their primacy rule (org-side
           JointOwnerTriggerHelper, 24 Aug) now refuses 60 outright - the buyer would
           hold 40 against a 60% owner - so the brink is unreachable through any door
           and our under-100 guard stands BEHIND theirs as defence in depth. What is
           still provable, and what this now proves: their refusal reaches the rep
           verbatim through our pipeline, and a compliant pair still lands. */
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account first  = newPerson('PCT1', 'Resident');
        Account second = newPerson('PCT2', 'Resident');

        Test.startTest();
        String msg = refusalFrom(req(so, first.Id, 60));
        SalesConsoleJointOwnerService.addOwner(req(so, first.Id, 30));
        SalesConsoleJointOwnerService.OwnersDTO ok =
            SalesConsoleJointOwnerService.addOwner(req(so, second.Id, 29));
        Test.stopTest();

        System.assertNotEquals(null, msg,
            '60% leaves the buyer 40 against a 60% owner - MODON\'s rule refuses it.');
        System.assert(msg.containsIgnoreCase('largest percentage'),
            'Their trigger\'s own sentence must reach the rep unparaphrased. Got: ' + msg);
        System.assertEquals(41, ok.primaryShare, '30 + 29 leaves the buyer 41%.');
    }

    /** G4. Six is the ceiling, structurally and in MODON's trigger. */
    @isTest(SeeAllData=true)
    static void testSeventhOwnerIsRefused() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');

        /* Seeded by direct DML, not through addOwner, and outside the metered block.
           Six addOwner calls cost ~60 SOQL between them and the assertion here is about
           the seventh. Writing the rows directly also makes the point sharper: the guard
           counts what is on the unit, whoever put it there. */
        List<Account> six = new List<Account>();
        for (Integer i = 1; i <= 6; i++) {
            six.add(new Account(
                FirstName = 'JOTest', LastName = 'Max' + i,
                RecordTypeId = personRecordTypeId(),
                UAE_Resident_Status__pc = 'Resident',
                EIDNumber__pc = 'JOTMAX' + i
            ));
        }
        Database.DMLOptions dmo = new Database.DMLOptions();
        dmo.DuplicateRuleHeader.allowSave = true;
        Database.insert(six, dmo);
        List<JointOwner__c> seed = new List<JointOwner__c>();
        for (Account a : six) {
            seed.add(new JointOwner__c(
                JointOwnerAccount__c   = a.Id,
                SalesOrder__c          = so.Id,
                OwnershipPercentage__c = 10,
                RelationshipType__c    = 'Joint Owner P-P',
                RelationshipSubType__c = 'Friend'
            ));
        }
        insert seed;
        Account seventh = newPerson('MAX7', 'Resident');

        Test.startTest();
        String msg = refusalFrom(req(so, seventh.Id, 5));
        Test.stopTest();

        System.assertNotEquals(null, msg, 'A seventh joint owner must be refused.');
        System.assert(msg.contains('6') || msg.containsIgnoreCase('maximum'),
            'And the message must name the limit. Got: ' + msg);
        System.assertEquals(6, [SELECT COUNT() FROM JointOwner__c WHERE SalesOrder__c = :so.Id],
            'Six rows, not seven.');
    }

    // ── the cut-off ───────────────────────────────────────────────────────

    /**
     * G3, primary signal. The contract is signed; nobody joins it now.
     *
     * SPAStatus__c is the ladder MODON maintains and the only one of the three signals
     * that is populated broadly enough to gate on: SPA_Send_Date_for_Signature__c is
     * blank on every order in this org and on 7,825 preprod orders that are already past
     * SPA generation.
     */
    @isTest(SeeAllData=true)
    static void testSignedOrderIsRefused() {
        SalesOrder__c so = orderAtSpaStatus('SPA Signed (Modon)');
        System.assert(so != null, 'No SPA-signed Sales Order in this org - the cut-off cannot be proved.');
        Account person = newPerson('SIGNED', 'Resident');

        Test.startTest();
        String msg = refusalFrom(req(so, person.Id, 20));
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        System.assertNotEquals(null, msg, 'A signed SPA must refuse a new joint owner.');
        System.assert(msg.containsIgnoreCase('service request'),
            'And the message must name the route out. Got: ' + msg);
        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c
                                WHERE SalesOrder__c = :so.Id AND JointOwnerAccount__c = :person.Id],
            'Nothing was written.');

        Boolean found = false;
        for (SalesConsoleJointOwnerService.UnitDTO u : dto.units) {
            if (u.salesOrderId == so.Id) {
                found = true;
                System.assertEquals(false, u.open, 'The panel must show this unit as closed.');
                System.assertNotEquals(null, u.closedReason, 'And say why.');
            }
        }
        System.assert(found, 'The closed unit is still listed - it is part of the booking.');
    }

    /** G3 again, one rung earlier: the customer has signed and Modon is checking. */
    @isTest(SeeAllData=true)
    static void testOrderAwaitingValidationIsRefused() {
        SalesOrder__c so = orderAtSpaStatusOrStamped('Pending for Validation');
        System.assert(so != null, 'No Sales Order that can be put at Pending for Validation.');
        Account person = newPerson('PENDVAL', 'Resident');

        Test.startTest();
        String msg = refusalFrom(req(so, person.Id, 20));
        Test.stopTest();

        System.assertNotEquals(null, msg, 'An envelope already with the customer must refuse.');
        System.assert(msg.containsIgnoreCase('service request'),
            'The message names the route out. Got: ' + msg);
    }

    /**
     * SPA Generated is OPEN, and warns.
     *
     * The document exists with the current owner list merged into it, but nothing has
     * gone to the customer, so it can be regenerated. Refusing here would be stricter
     * than the business behaves - 17 joint owners sit on such orders in preprod - so the
     * write succeeds and the answer says the SPA is now stale.
     */
    @isTest(SeeAllData=true)
    static void testGeneratedSpaWarnsButDoesNotRefuse() {
        SalesOrder__c so = orderAtSpaStatusOrStamped('SPA Generated');
        System.assert(so != null, 'No Sales Order that can be put at SPA Generated.');
        Account person = newPerson('SPAGEN', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 5));
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c
                                WHERE SalesOrder__c = :so.Id AND JointOwnerAccount__c = :person.Id],
            'A generated-but-unsent SPA does not block the write.');
        System.assertNotEquals(null, dto.warning, 'But it does warn.');
        System.assert(dto.warning.containsIgnoreCase('regenerat'),
            'And the warning says what has to happen. Got: ' + dto.warning);
    }

    /**
     * G3, second signal. Kept because when the date IS set the envelope definitely went
     * out, whatever SPAStatus__c says - two preprod orders disagree, and one carries a
     * joint owner. No order in this org has one, so the test stamps a real order and
     * lets the transaction roll it back.
     */
    @isTest(SeeAllData=true)
    static void testSpaSendDateAloneClosesTheGate() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order to stamp.');
        Account person = newPerson('SENTDATE', 'Resident');

        Test.startTest();
        update new SalesOrder__c(Id = so.Id, SPA_Send_Date_for_Signature__c = System.today());
        String msg = refusalFrom(req(so, person.Id, 20));
        Test.stopTest();

        System.assertNotEquals(null, msg,
            'A send date on its own closes the gate, even at SPA Not Generated.');
        System.assert(msg.containsIgnoreCase('service request'),
            'And it names the route out. Got: ' + msg);
    }

    // ── multi-unit ────────────────────────────────────────────────────────

    /**
     * A person-account booking of two or more open units, none of them owned yet.
     *
     * 1.x - and EVERY order of that booking has to be open, not merely the ones this method
     * kept. The old version filtered as it collected, so a booking could be offered as a clean
     * two-unit basket while a third order of the same opportunity was dead or had its SPA out.
     * getOwners() counts the units of the BOOKING, so the service then reported one more unit
     * than an empty-target write could ever cover ("4 units, 3 rows", "Every unit is covered:
     * expected 0, actual 1") - or refused the write outright ("The SPA for PT-001 has already
     * been sent…", SO-15062 at Completed). Now the candidate bookings are found first and then
     * read whole, and one unusable order disqualifies the whole booking.
     */
    private static List<SalesOrder__c> openBasket() {
        Set<Id> candidates = new Set<Id>();
        for (SalesOrder__c so : [
            SELECT Opportunity__c
            FROM SalesOrder__c
            WHERE Opportunity__r.Account.IsPersonAccount = true
            AND SPA_Send_Date_for_Signature__c = null
            AND (SPAStatus__c = null OR SPAStatus__c = 'SPA Not Generated')
            ORDER BY CreatedDate DESC
            LIMIT 400
        ]) {
            candidates.add(so.Opportunity__c);
        }
        if (candidates.isEmpty()) {
            return null;
        }

        Map<Id, List<SalesOrder__c>> byOpp = new Map<Id, List<SalesOrder__c>>();
        Set<Id> unusable = new Set<Id>();
        for (SalesOrder__c so : [
            SELECT Id, Name, Opportunity__c, Status__c, SPAStatus__c, Source_Entity__c,
                   SPA_Send_Date_for_Signature__c, Unit__c, Unit__r.Name
            FROM SalesOrder__c
            WHERE Opportunity__c IN :candidates
            ORDER BY Opportunity__c, Name
        ]) {
            if (!byOpp.containsKey(so.Opportunity__c)) {
                byOpp.put(so.Opportunity__c, new List<SalesOrder__c>());
            }
            byOpp.get(so.Opportunity__c).add(so);
            /* the three gates checkWritable() applies, in its own terms */
            Boolean open = so.SPA_Send_Date_for_Signature__c == null
                && (String.isBlank(so.SPAStatus__c)
                        || so.SPAStatus__c.equalsIgnoreCase('SPA Not Generated'))
                && !inAny(DEAD, so.Status__c)
                && !inAny(SPA_OUT, so.Status__c)
                && so.Source_Entity__c != EGYPT;
            if (!open) {
                unusable.add(so.Opportunity__c);
            }
        }

        Set<Id> owned = new Set<Id>();
        for (JointOwner__c jo : [
            SELECT SalesOrder__c FROM JointOwner__c WHERE SalesOrder__c != null
        ]) {
            owned.add(jo.SalesOrder__c);
        }
        for (Id oppId : byOpp.keySet()) {
            if (unusable.contains(oppId)) {
                continue;
            }
            List<SalesOrder__c> basket = byOpp.get(oppId);
            if (basket.size() < 2) {
                continue;
            }
            Boolean clean = true;
            for (SalesOrder__c so : basket) {
                if (owned.contains(so.Id)) { clean = false; }
            }
            if (clean) { return basket; }
        }
        return null;
    }

    /**
     * The default that makes the common case free.
     *
     * One co-owner across the whole basket is the median in the data, so it should cost
     * no decision: an empty unit list means every open unit, and that is N rows sharing
     * one Account - exactly the shape MODON's own clone-per-order behaviour produces.
     */
    @isTest(SeeAllData=true)
    static void testAnEmptyUnitListCoversTheWholeBasket() {
        List<SalesOrder__c> basket = openBasket();
        System.assert(basket != null,
            'No multi-unit person-account booking with unowned units in this org - the '
            + 'basket behaviour cannot be proved without one.');
        Account person = newPerson('BASKET', 'Resident');

        SalesConsoleJointOwnerService.AddOwnerInput r = req(basket[0], person.Id, 25);
        r.targetOrderIds = null;   // every open unit

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto = SalesConsoleJointOwnerService.addOwner(r);
        Test.stopTest();

        List<JointOwner__c> rows = [
            SELECT Id, SalesOrder__c FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id
        ];
        System.assertEquals(basket.size(), rows.size(),
            'One row per unit - ' + basket.size() + ' units, ' + rows.size() + ' rows.');
        Set<Id> written = new Set<Id>();
        for (JointOwner__c jo : rows) { written.add(jo.SalesOrder__c); }
        for (SalesOrder__c so : basket) {
            System.assert(written.contains(so.Id), so.Name + ' was left without the owner.');
        }
        System.assertEquals(0, dto.unitsWithNoJointOwner.size(), 'Every unit is covered.');
        System.assert(dto.coverageLine != null && dto.coverageLine.containsIgnoreCase('All'),
            'And the coverage line says so. Got: ' + dto.coverageLine);
    }

    /**
     * The 36% finding, in a test.
     *
     * Putting one person on one unit of a basket is legitimate - a parent buying one
     * villa per child does exactly that - so it is allowed. What is not allowed is
     * silence about the units that end up with nobody, because that silence is how 33
     * units in preprod ended up uncovered on bookings where every other unit had a
     * co-owner. The line names them, by unit, always.
     */
    @isTest(SeeAllData=true)
    static void testCoverageLineNamesTheUnitsWithNobody() {
        List<SalesOrder__c> basket = openBasket();
        System.assert(basket != null, 'No multi-unit booking with unowned units in this org.');
        Account person = newPerson('PARTIAL', 'Resident');

        SalesConsoleJointOwnerService.AddOwnerInput r = req(basket[0], person.Id, 25);
        r.targetOrderIds = new List<Id>{ basket[0].Id };   // one unit only, deliberately

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto = SalesConsoleJointOwnerService.addOwner(r);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id],
            'A per-unit allocation writes one row, not a basket-wide one.');
        System.assertEquals(basket.size() - 1, dto.unitsWithNoJointOwner.size(),
            'Every other unit is reported as having nobody.');
        System.assertNotEquals(null, dto.coverageLine, 'The line is never absent on a basket.');
        String expected = basket[1].Unit__r != null && basket[1].Unit__r.Name != null
            ? basket[1].Unit__r.Name : basket[1].Name;
        System.assert(dto.coverageLine.contains(expected),
            'It names the empty unit by name, not by Sales Order number. Got: ' + dto.coverageLine);
    }

    // ── the savepoint, and the update path ────────────────────────────────

    /**
     * A refused add leaves nothing behind, including the person it had to create.
     *
     * The Person Account is created before the per-unit guards run, so without the
     * savepoint a rep who picked a closed unit would mint a stranger's account on every
     * attempt and never see it.
     */
    @isTest(SeeAllData=true)
    static void testARefusedAddLeavesNoOrphanAccount() {
        SalesOrder__c closed = orderAtSpaStatus('SPA Signed (Modon)');
        System.assert(closed != null, 'No closed Sales Order to be refused by.');

        SalesConsoleJointOwnerService.AddOwnerInput r =
            new SalesConsoleJointOwnerService.AddOwnerInput();
        r.opportunityId       = closed.Opportunity__c;
        r.salesOrderId        = closed.Id;
        r.targetOrderIds      = new List<Id>{ closed.Id };
        r.accountId           = null;                    // create them
        r.firstName           = 'JOTest';
        r.lastName            = 'Orphan';
        r.residentStatus      = 'Resident';
        r.eidNumber           = 'JOTORPHAN';
        r.share               = 20;
        r.relationshipType    = 'Joint Owner P-P';
        r.relationshipSubType = 'Spouse';

        Test.startTest();
        String msg = refusalFrom(r);
        Test.stopTest();

        System.assertNotEquals(null, msg, 'The closed unit must refuse.');
        System.assertEquals(0,
            [SELECT COUNT() FROM Account WHERE EIDNumber__pc = 'JOTORPHAN'],
            'And the account created on the way in must be rolled back with it.');
    }

    /** An owner's share can be corrected without going near a delete. */
    @isTest(SeeAllData=true)
    static void testUpdateChangesTheShare() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('UPD', 'Resident');
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));

        SalesConsoleJointOwnerService.UpdateOwnerInput u =
            new SalesConsoleJointOwnerService.UpdateOwnerInput();
        u.opportunityId       = so.Opportunity__c;
        u.salesOrderId        = so.Id;
        u.accountId           = person.Id;
        u.targetOrderIds      = new List<Id>{ so.Id };
        u.share               = 45;
        u.relationshipType    = 'Partner';
        u.relationshipSubType = 'Friend';

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto = SalesConsoleJointOwnerService.updateOwner(u);
        Test.stopTest();

        JointOwner__c jo = [
            SELECT OwnershipPercentage__c, RelationshipType__c, RelationshipSubType__c
            FROM JointOwner__c WHERE SalesOrder__c = :so.Id AND JointOwnerAccount__c = :person.Id
        ];
        System.assertEquals(45, jo.OwnershipPercentage__c, 'The Ownership % moved.');
        System.assertEquals('Partner', jo.RelationshipType__c, 'So did the relationship.');
        System.assertEquals('Friend', jo.RelationshipSubType__c, 'And its sub-type.');
        System.assertEquals(55, dto.primaryShare, 'The primary owner holds the rest.');
    }

    /**
     * An empty unit list on an EDIT means "the units they are already on".
     *
     * It means the opposite on an add - every open unit - and the asymmetry is the point:
     * silence on an add is the common case and should be free, while silence on an edit
     * must never expand someone onto units the caller never named.
     */
    @isTest(SeeAllData=true)
    static void testUpdateWithNoUnitsTouchesOnlyTheirOwn() {
        List<SalesOrder__c> basket = openBasket();
        System.assert(basket != null, 'No multi-unit booking with unowned units in this org.');
        Account person = newPerson('UPDNONE', 'Resident');
        SalesConsoleJointOwnerService.addOwner(req(basket[0], person.Id, 20));  // ONE unit

        SalesConsoleJointOwnerService.UpdateOwnerInput u =
            new SalesConsoleJointOwnerService.UpdateOwnerInput();
        u.opportunityId       = basket[0].Opportunity__c;
        u.salesOrderId        = basket[0].Id;
        u.accountId           = person.Id;
        u.targetOrderIds      = null;              // say nothing
        u.share               = 35;
        u.relationshipType    = 'Joint Owner P-P';
        u.relationshipSubType = 'Spouse';

        Test.startTest();
        SalesConsoleJointOwnerService.updateOwner(u);
        Test.stopTest();

        List<JointOwner__c> rows = [
            SELECT SalesOrder__c, OwnershipPercentage__c
            FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id
        ];
        System.assertEquals(1, rows.size(),
            'Saying nothing on an edit must not spread them across the basket.');
        System.assertEquals(basket[0].Id, rows[0].SalesOrder__c, 'Still the unit they were on.');
        System.assertEquals(35, rows[0].OwnershipPercentage__c, 'With the new Ownership %.');
    }

    /**
     * Narrowing the unit set is a removal, and the console does not remove joint owners.
     *
     * MODON's afterDeleteMethod is empty, so a delete leaves JO1__c..JO6__c pointing at
     * the removed person and the SPA, the portal and every letter keep seeing them. The
     * request is refused with the route rather than half-honoured.
     */
    @isTest(SeeAllData=true)
    static void testUpdateCannotTakeAnOwnerOffAUnit() {
        List<SalesOrder__c> basket = openBasket();
        System.assert(basket != null, 'No multi-unit booking with unowned units in this org.');
        Account person = newPerson('NODROP', 'Resident');

        SalesConsoleJointOwnerService.AddOwnerInput r = req(basket[0], person.Id, 20);
        r.targetOrderIds = null;                          // on every unit
        SalesConsoleJointOwnerService.addOwner(r);

        SalesConsoleJointOwnerService.UpdateOwnerInput u =
            new SalesConsoleJointOwnerService.UpdateOwnerInput();
        u.opportunityId       = basket[0].Opportunity__c;
        u.salesOrderId        = basket[0].Id;
        u.accountId           = person.Id;
        u.targetOrderIds      = new List<Id>{ basket[0].Id };   // drop the others
        u.share               = 20;
        u.relationshipType    = 'Joint Owner P-P';
        u.relationshipSubType = 'Spouse';

        Test.startTest();
        String msg;
        try {
            SalesConsoleJointOwnerService.updateOwner(u);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, msg, 'Dropping a unit must be refused.');
        System.assert(msg.containsIgnoreCase('service request'),
            'And the message must name the route. Got: ' + msg);
        System.assertEquals(basket.size(),
            [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id],
            'Every row survives the refusal.');
    }

    /**
     * The guards read without sharing, and this proves they agree with what the rep sees.
     *
     * Running as an administrator nothing is hidden, so hiddenOwnerCount must be zero and
     * the counts must match. The value of the assertion is the other direction: if the
     * two ever disagree for a rep, the panel says so instead of quietly under-reporting.
     */
    @isTest(SeeAllData=true)
    static void testTheGuardAgreesWithWhatTheRepCanSee() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('VISIBLE', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        for (SalesConsoleJointOwnerService.UnitDTO u : dto.units) {
            if (u.salesOrderId == so.Id) {
                System.assertEquals(1, u.ownerCount, 'The guard counted the row it wrote.');
                System.assertEquals(0, u.hiddenOwnerCount,
                    'Nothing is hidden from this user, so the two reads must agree.');
                System.assertEquals(30, u.allocatedShare, 'And the Ownership % total is the guard\'s.');
            }
        }
    }

    /**
     * Egypt is refused - and this org cannot prove it.
     *
     * The guard is real (checkWritable), but the single Modon Egypt Sales Order in this
     * sandbox carries no Opportunity, so resolve() can never reach it. Recorded here
     * rather than passed over in silence: verify this branch in UAT or preprod, which
     * hold 2,678 Egypt orders and 398 joint owners on them.
     */
    @isTest(SeeAllData=true)
    static void testEgyptBookingIsRefusedWhereOneExists() {
        List<SalesOrder__c> egypt = [
            SELECT Id, Name, Opportunity__c, Status__c
            FROM SalesOrder__c
            WHERE Source_Entity__c = :EGYPT
            AND Opportunity__c != null
            AND Opportunity__r.Account.IsPersonAccount = true
            LIMIT 1
        ];
        if (egypt.isEmpty()) {
            System.assertEquals(0, egypt.size(),
                'No Modon Egypt booking reachable from an Opportunity in this org, so the '
                + 'Egypt guard is not covered here. Prove it in UAT or preprod.');
            return;
        }
        Account person = newPerson('EGYPT', 'Resident');
        Test.startTest();
        String msg = refusalFrom(req(egypt[0], person.Id, 20));
        Test.stopTest();

        System.assertNotEquals(null, msg, 'A Modon Egypt booking must be refused.');
        System.assert(msg.containsIgnoreCase('Egypt'),
            'And the message must point at the Egypt screen. Got: ' + msg);
    }

    // ══════════════════════════════════════════════════════════════════════
    // 1.1 - MSC-082, identity verification per party
    // ══════════════════════════════════════════════════════════════════════

    /** Everything sendKYCForm demands, so this person can actually be sent a link. */
    private static void giveContactDetails(Id accountId, String email, String mobile) {
        Account a = new Account(
            Id                      = accountId,
            PersonEmail             = email,
            PersonMobilePhone       = mobile,
            Nationality__pc         = 'United Arab Emirates',
            UAE_Resident_Status__pc = 'Resident'
        );
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        Database.update(a, o);
    }

    private static SalesConsoleJointOwnerService.PartyDTO partyFor(
        SalesConsoleJointOwnerService.OwnersDTO dto, Id accountId
    ) {
        for (SalesConsoleJointOwnerService.PartyDTO p : dto.parties) {
            if (p.accountId == accountId) {
                return p;
            }
        }
        return null;
    }

    /**
     * The panel cannot offer a Send it knows will do nothing, so the reason has to
     * arrive with the person. newPerson gives a last name, a residency and a document -
     * exactly what phase 1 asks for - and that is three fields short of a link.
     */
    @isTest(SeeAllData=true)
    static void testAJointOwnerCarriesTheirOwnVerificationState() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('VSTATE', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));
        Test.stopTest();

        SalesConsoleJointOwnerService.PartyDTO p = partyFor(dto, person.Id);
        System.assertNotEquals(null, p, 'The person we just added must be on the picture.');
        System.assertEquals('NOT_SENT', p.verificationStatus,
            'Nobody has sent them anything.');
        System.assertEquals(true, p.canEverVerify,
            'They are a person account, so this route is open to them in principle.');
        System.assertEquals(false, p.canSendVerification,
            'But not today: they have no email, mobile or nationality.');
        System.assertEquals(true, p.detailsMissing,
            'And contact detail is the ONLY thing in the way, which is what turns the '
            + 'row\'s action from a dead Send into Add details.');
        System.assertNotEquals(null, p.verificationBlockedReason, 'The reason is never absent.');
        System.assert(p.verificationBlockedReason.contains(person.Name),
            'It names THEM, not "the customer" - there are two people on this booking. '
            + 'Got: ' + p.verificationBlockedReason);
        System.assert(p.verificationBlockedReason.containsIgnoreCase('email'),
            'And it names what is missing. Got: ' + p.verificationBlockedReason);

        SalesConsoleJointOwnerService.PartyDTO primary = dto.parties[0];
        System.assertEquals(true, primary.isPrimary, 'The buyer is the first party.');
        System.assertNotEquals(null, primary.verificationStatus,
            'The buyer carries the same state as everyone else - they are a party too.');
        System.assert(dto.verifiableCount >= 1,
            'The tally counts people who could ever verify. Got: ' + dto.verifiableCount);
        System.assert(dto.verifiedCount <= dto.verifiableCount,
            'And it can never exceed its own denominator.');
    }

    /**
     * THE GUARD THAT MATTERS MOST IN THIS PHASE.
     *
     * Without it any Account Id posted from a browser starts a real identity journey,
     * sends a real person a real email and stamps their record.
     */
    @isTest(SeeAllData=true)
    static void testVerificationCannotBeSentToSomeoneNotOnThisBooking() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account stranger = newPerson('VSTRANGER', 'Resident');
        giveContactDetails(stranger.Id, 'jotest.stranger@example.com', '+971500000001');

        String msg;
        Test.startTest();
        try {
            SalesConsoleJointOwnerService.sendVerification(
                so.Opportunity__c, so.Id, stranger.Id);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, msg,
            'An account that is not on this booking must be refused outright, however '
            + 'complete its own details are.');
        System.assert(msg.containsIgnoreCase('not on this booking'), 'Got: ' + msg);

        Account after = [SELECT KYC_Send_Date_Time__c, KYCUnitName__pc FROM Account WHERE Id = :stranger.Id];
        System.assertEquals(null, after.KYCUnitName__pc,
            'And nothing may have been written to them on the way out.');
    }

    /** The refusal is the party's own sentence, so the drawer and the row agree. */
    @isTest(SeeAllData=true)
    static void testVerificationIsRefusedWhileContactDetailsAreMissing() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('VNODETAIL', 'Resident');
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 25));

        String msg;
        Test.startTest();
        try {
            SalesConsoleJointOwnerService.sendVerification(so.Opportunity__c, so.Id, person.Id);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, msg, 'They cannot be sent anything yet.');
        System.assert(msg.contains(person.Name),
            'The refusal names the person it is about. Got: ' + msg);
    }

    /**
     * The send itself. enqueueSend deliberately does not enqueue under test - see its
     * comment - so what is provable here is the half that runs synchronously, and it is
     * the half that decides what the customer's form says.
     */
    @isTest(SeeAllData=true)
    static void testSendVerificationStampsTheUnitAndReportsSending() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        System.assertNotEquals(null, so.Unit__c, 'The order under test must carry a unit.');
        Account person = newPerson('VSEND', 'Resident');
        giveContactDetails(person.Id, 'jotest.vsend@example.com', '+971500000002');
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 20));

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.sendVerification(so.Opportunity__c, so.Id, person.Id);
        Test.stopTest();

        SalesConsoleJointOwnerService.PartyDTO p = partyFor(dto, person.Id);
        System.assertNotEquals(null, p, 'They are still on the picture that comes back.');
        System.assertEquals('SENDING', p.verificationStatus,
            'SENDING, not SENT: the link does not exist until the queueable has run and '
            + 'MODON\'s Flow has stamped the send date. The console must not claim '
            + 'something it cannot yet see.');

        Account after = [SELECT KYCUnitName__pc FROM Account WHERE Id = :person.Id];
        System.assertEquals(so.Unit__r.Name, after.KYCUnitName__pc,
            'THE POINT OF THE WHOLE PHASE. A joint owner is not the primary contact on '
            + 'any Sales Order, so MODON\'s own getLatestUnitInfo finds nothing for them '
            + 'and this stamp is the only thing that names the unit they are co-buying. '
            + 'If it is blank, their verification form arrives naming no property.');
    }

    /**
     * BLANK FIELDS ONLY. This is the rule that lets the console write to a MODON
     * Account at all, and it is the one that must never quietly stop being true.
     */
    @isTest(SeeAllData=true)
    static void testUpdateFillsBlankContactDetailsAndNeverOverwritesOne() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('VFILL', 'Resident');
        /* An email they already have, and nothing else of the four. */
        Account seed = new Account(Id = person.Id, PersonEmail = 'jotest.keepme@example.com');
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        Database.update(seed, o);

        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));

        SalesConsoleJointOwnerService.UpdateOwnerInput u =
            new SalesConsoleJointOwnerService.UpdateOwnerInput();
        u.opportunityId       = so.Opportunity__c;
        u.salesOrderId        = so.Id;
        u.accountId           = person.Id;
        u.targetOrderIds      = new List<Id>{ so.Id };
        u.share               = 30;
        u.relationshipType    = 'Joint Owner P-P';
        u.relationshipSubType = 'Spouse';
        u.email               = 'jotest.overwrite@example.com';
        u.mobile              = '+971500000003';
        u.nationality         = 'United Arab Emirates';

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto = SalesConsoleJointOwnerService.updateOwner(u);
        Test.stopTest();

        Account after = [
            SELECT PersonEmail, PersonMobilePhone, Nationality__pc, UAE_Resident_Status__pc
            FROM Account WHERE Id = :person.Id
        ];
        System.assertEquals('jotest.keepme@example.com', after.PersonEmail,
            'THE EMAIL THEY ALREADY HAD MUST SURVIVE. This is a MODON account, quite '
            + 'possibly the buyer of somebody else\'s booking, and an overwrite would put '
            + 'a mistyped address over a good one with nothing anywhere to say so.');
        System.assertEquals('+971500000003', after.PersonMobilePhone,
            'The blank mobile is filled - there was nothing to lose.');
        System.assertEquals('United Arab Emirates', after.Nationality__pc,
            'And the blank nationality with it.');

        SalesConsoleJointOwnerService.PartyDTO p = partyFor(dto, person.Id);
        System.assertEquals(true, p.canSendVerification,
            'With all four present they can now be sent a link, which is the entire '
            + 'reason those fields are on the edit form.');
        System.assertEquals(false, p.detailsMissing, 'Nothing is missing any more.');
        System.assertEquals(null, p.verificationBlockedReason, 'So there is no reason to give.');
    }

    /** Nothing to fill is not a write. */
    @isTest(SeeAllData=true)
    static void testUpdateWithNoContactDetailsTouchesTheAccountNotAtAll() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('VNOFILL', 'Resident');
        giveContactDetails(person.Id, 'jotest.vnofill@example.com', '+971500000004');
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));

        Datetime before = [SELECT LastModifiedDate FROM Account WHERE Id = :person.Id].LastModifiedDate;

        SalesConsoleJointOwnerService.UpdateOwnerInput u =
            new SalesConsoleJointOwnerService.UpdateOwnerInput();
        u.opportunityId       = so.Opportunity__c;
        u.salesOrderId        = so.Id;
        u.accountId           = person.Id;
        u.targetOrderIds      = new List<Id>{ so.Id };
        u.share               = 40;
        u.relationshipType    = 'Joint Owner P-P';
        u.relationshipSubType = 'Spouse';
        /* Sent, and every one of them already has a value on the record. */
        u.email               = 'jotest.ignored@example.com';
        u.mobile              = '+971599999999';

        Test.startTest();
        SalesConsoleJointOwnerService.updateOwner(u);
        Test.stopTest();

        Account after = [
            SELECT PersonEmail, PersonMobilePhone, LastModifiedDate
            FROM Account WHERE Id = :person.Id
        ];
        System.assertEquals('jotest.vnofill@example.com', after.PersonEmail, 'Untouched.');
        System.assertEquals('+971500000004', after.PersonMobilePhone, 'Untouched.');
        System.assertEquals(before, after.LastModifiedDate,
            'And no DML at all fired against the account - a fill with nothing to fill '
            + 'must not stamp somebody else\'s record as modified by us.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // 1.2 - MSC-083 · compliance state, per party
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Somebody who has not verified cannot be sent to compliance, and the row says why.
     *
     * The reason is what the panel prints instead of a button, so it has to name the
     * PERSON - a joint-owner booking has two of them and "the customer" is about the
     * wrong one. It also has to name the same obstacle the compliance service itself
     * would refuse on, or the rep is told one thing here and another when they press.
     */
    @isTest(SeeAllData=true)
    static void testAJointOwnerCarriesTheirOwnComplianceState() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('CSTATE', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));
        Test.stopTest();

        SalesConsoleJointOwnerService.PartyDTO p = partyFor(dto, person.Id);
        System.assertNotEquals(null, p, 'The person we just added must be on the picture.');
        System.assertEquals(false, p.complianceSubmitted,
            'Nobody has sent a brand new person anywhere.');
        System.assertEquals(false, p.canCheckCompliance,
            'And they cannot be checked: they have not finished identity verification.');
        System.assertNotEquals(null, p.complianceBlockedReason, 'The reason is never absent.');
        System.assert(p.complianceBlockedReason.contains(person.Name),
            'It names THEM, not "the customer". Got: ' + p.complianceBlockedReason);
        System.assert(p.complianceBlockedReason.containsIgnoreCase('identity verification'),
            'And it names the stage they are actually stuck at, which is the one before '
            + 'this. Got: ' + p.complianceBlockedReason);
    }

    /**
     * THE TALLY CAN NEVER EXCEED ITS OWN DENOMINATOR, and the denominator is deliberately
     * the same population as the verification one - the same people, counted by Account
     * and not by row. Two fractions with two denominators on one panel would leave the
     * rep working out which of them they were being asked to act on.
     */
    @isTest(SeeAllData=true)
    static void testTheComplianceTallyIsBoundedByTheSamePeople() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('CTALLY', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));
        Test.stopTest();

        System.assert(dto.complianceSubmittedCount <= dto.verifiableCount,
            'Got ' + dto.complianceSubmittedCount + ' of ' + dto.verifiableCount);
        System.assert(dto.verifiedCount <= dto.verifiableCount,
            'And so is the verification one, off the same population. Got '
            + dto.verifiedCount + ' of ' + dto.verifiableCount);

        /* NOT ASSERTED: that verifiedCount >= complianceSubmittedCount.
           It is what MODON's pipeline produces - nobody reaches Passfort without
           finishing identity verification - but it is a property of the DATA and not of
           this code, and the sandbox holds accounts stamped by hand in either order. A
           test that fails on legitimate records is worse than one that does not make the
           claim. The bound above is structural: both counts are incremented inside one
           loop, guarded by the same Set<Id>, so neither can outrun the denominator
           whatever the records say. */
    }

    /**
     * THREE WAYS OF KNOWING, and this is the one 1.2 missed.
     *
     * SalesConsoleComplianceService has always counted an open PassfortTransaction__c as
     * submitted, because a profile id and an approval status both arrive MINUTES after
     * the transaction is created. A panel reading only the approval status said "not
     * sent" about somebody who had just been sent, and offered to send them again. The
     * two must agree, so this asserts against that class's own answer rather than
     * against a copy of the rule.
     */
    @isTest(SeeAllData=true)
    static void testSubmittedMeansTheSameThingHereAsItDoesToCompliance() {
        List<JointOwner__c> jos = [
            SELECT JointOwnerAccount__c, SalesOrder__r.Opportunity__c
            FROM JointOwner__c
            WHERE JointOwnerAccount__r.IsPersonAccount = true
            AND JointOwnerAccount__r.PersonContactId != null
            AND JointOwnerAccount__r.KYC_Completed_Date__c != null
            AND JointOwnerAccount__r.UAE_Resident_Status__pc != null
            AND SalesOrder__r.Opportunity__c != null
            AND SalesOrder__r.Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
            LIMIT 1
        ];
        if (jos.isEmpty()) {
            /* Soft: this needs a joint owner who has finished identity verification, and
               an org without one is not a failing org. The two tests above prove the
               state on data this class creates. */
            return;
        }
        JointOwner__c jo = jos[0];

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO owners =
            SalesConsoleJointOwnerService.getOwners(jo.SalesOrder__r.Opportunity__c, null);
        SalesConsoleComplianceService.ChecklistDTO check =
            SalesConsoleComplianceService.getChecklist(
                jo.SalesOrder__r.Opportunity__c, null, jo.JointOwnerAccount__c
            );
        Test.stopTest();

        SalesConsoleJointOwnerService.PartyDTO p = partyFor(owners, jo.JointOwnerAccount__c);
        System.assertNotEquals(null, p, 'The joint owner must be on the picture.');
        System.assertEquals(true, p.canCheckCompliance,
            'A verified joint owner on a live order can be checked.');
        System.assertEquals(check.alreadySubmitted, p.complianceSubmitted,
            'The row and the panel must not disagree about whether this person has '
            + 'already been sent. Row said ' + p.complianceSubmitted
            + ', compliance said ' + check.alreadySubmitted);
    }

    /**
     * A PARTY'S COMPLIANCE SUBMISSION NAMES A UNIT THEY ACTUALLY CO-OWN.
     *
     * SalesConsoleComplianceService.liveSalesOrder returns the order the REP is looking
     * at. That is right for the buyer, who is on every order of their own booking, and
     * wrong for a joint owner on a basket: put them on unit A, leave the rep focused on
     * unit B, and the PassfortTransaction__c files against a unit that person has nothing
     * to do with. Nothing downstream would ever notice.
     *
     * NO SUCH BOOKING EXISTS IN DEV_1 - every joint owner here happens to be on every
     * live unit of their basket - so the gap is MADE, through the console's own addOwner
     * with a single target order, and the transaction rolls back. Handing the server the
     * worst case deliberately is the only way this assertion means anything.
     */
    @isTest(SeeAllData=true)
    static void testAPartyComplianceCheckNamesAUnitTheyActuallyHold() {
        List<SalesOrder__c> basket = openBasket();
        if (basket == null || basket.size() < 2) {
            return;
        }
        SalesOrder__c theirs   = basket[0];
        SalesOrder__c notTheirs = basket[1];
        Account person = newPerson('CBASKET', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.addOwner(req(theirs, person.Id, 25));
        /* The rep is on the OTHER unit of the same booking. */
        SalesConsoleComplianceService.ChecklistDTO dto =
            SalesConsoleComplianceService.getChecklist(
                theirs.Opportunity__c, notTheirs.Id, person.Id
            );
        Test.stopTest();

        System.assertEquals(theirs.Id, dto.salesOrderId,
            'The submission must be filed against the unit this person co-owns, not the '
            + 'one the rep happens to be looking at. Asked with ' + notTheirs.Id
            + ', got ' + dto.salesOrderId);
        /* And it is still a refusal, for the right reason - they have not verified. The
           unit is settled before that gate, which is why the answer carries it either
           way. */
        System.assertEquals(false, dto.available, 'A brand new person has not verified.');
        System.assert(
            dto.blockedReason != null
                && dto.blockedReason.containsIgnoreCase('identity verification'),
            'And the reason is the stage before this one. Got: ' + dto.blockedReason
        );
    }

    // ══════════════════════════════════════════════════════════════════════
    // 1.4 - MSC-084 · what the back catalogue says and the journey never could
    //
    // My Bookings lists every order the rep owns, cancelled and voided ones
    // deliberately included, where the journey only ever renders this panel on a
    // booking it is in the middle of making. Half of the orders in this org that
    // carry a joint owner are dead, and one carries sixty-four rows for one person
    // on one unit. Neither shape can be CREATED here - MODON's own updateJO refuses
    // a duplicate person on an order, and phase 1 refuses a dead one - so the two
    // that need real records find them, and say so rather than passing quietly if
    // this org ever stops having any.
    // ══════════════════════════════════════════════════════════════════════

    /** A booking every one of whose units is cancelled, voided or system cancelled. */
    private static SalesOrder__c bookingThatIsEntirelyDead() {
        Map<Id, List<SalesOrder__c>> byOpp = new Map<Id, List<SalesOrder__c>>();
        for (SalesOrder__c so : [
            SELECT Id, Name, Status__c, Opportunity__c
            FROM SalesOrder__c
            WHERE Opportunity__c != null
            AND Opportunity__r.Account.IsPersonAccount = true
            ORDER BY CreatedDate DESC
            LIMIT 800
        ]) {
            if (!byOpp.containsKey(so.Opportunity__c)) {
                byOpp.put(so.Opportunity__c, new List<SalesOrder__c>());
            }
            byOpp.get(so.Opportunity__c).add(so);
        }
        for (List<SalesOrder__c> booking : byOpp.values()) {
            Boolean allDead = true;
            for (SalesOrder__c so : booking) {
                if (!inAny(DEAD, so.Status__c)) {
                    allDead = false;
                }
            }
            if (allDead) {
                return booking[0];
            }
        }
        return null;
    }

    /**
     * A CANCELLED BOOKING IS NOT A BOOKING WITH NO UNIT, and until MSC-084 both were
     * told the same sentence.
     *
     * The journey never meets this: it renders the panel on a booking it is making.
     * My Bookings does, on seven of the fourteen orders in this org that carry a joint
     * owner - and a rep looking at a Voided order while being told it has no confirmed
     * unit yet is being told something false about a record in front of them.
     */
    @isTest(SeeAllData=true)
    static void testACancelledBookingSaysWhatActuallyHappenedToIt() {
        SalesOrder__c dead = bookingThatIsEntirelyDead();
        System.assert(dead != null,
            'This org has no booking whose every unit is dead, so the sentence under '
            + 'test cannot be reached. Seven such orders existed on 20 Aug 2026.');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(dead.Opportunity__c, dead.Id);
        Test.stopTest();

        System.assertEquals(false, dto.available,
            'A booking with no live unit has no arrangement to show.');
        System.assertNotEquals(null, dto.blockedReason, 'And it says why.');
        System.assert(!dto.blockedReason.containsIgnoreCase('no confirmed unit'),
            'It must not claim the booking never had a unit - it had one and it was '
            + dead.Status__c + '. Got: ' + dto.blockedReason);
        System.assert(
            dto.blockedReason.containsIgnoreCase(dead.Status__c)
                || dto.blockedReason.containsIgnoreCase('cancelled'),
            'The sentence names the stored status, quoted rather than paraphrased, the '
            + 'same way the SPA refusal does. Status was ' + dead.Status__c
            + ', got: ' + dto.blockedReason
        );
    }

    /** And the sentence it replaced is still the right one where it belongs. */
    @isTest
    static void testABookingWithNoUnitAtAllStillSaysThat() {
        Account buyer = newPerson('NOUNIT', 'Resident');
        Opportunity opp = opportunityFor(buyer);

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(opp.Id, null);
        Test.stopTest();

        System.assertEquals(false, dto.available, 'There is nothing to own yet.');
        System.assert(
            dto.blockedReason != null
                && dto.blockedReason.containsIgnoreCase('no confirmed unit'),
            'A booking that never reached a Sales Order is exactly the case that '
            + 'sentence is for. Got: ' + dto.blockedReason
        );
    }

    /** A Sales Order carrying more than one row for the SAME person. It cannot be
     *  made - MODON's updateJO refuses a duplicate on an order - so it is found. */
    private static Id orderWithDuplicateRowsForOnePerson() {
        Set<String> seen = new Set<String>();
        for (JointOwner__c jo : [
            SELECT SalesOrder__c, JointOwnerAccount__c
            FROM JointOwner__c
            WHERE SalesOrder__c != null AND JointOwnerAccount__c != null
            LIMIT 2000
        ]) {
            String key = String.valueOf(jo.SalesOrder__c) + '|'
                + String.valueOf(jo.JointOwnerAccount__c);
            if (seen.contains(key)) {
                return jo.SalesOrder__c;
            }
            seen.add(key);
        }
        return null;
    }

    /**
     * A UNIT IS NAMED ONCE, HOWEVER MANY ROWS SAY IT.
     *
     * holdings is the ledger and keeps every row, because a row is a record and hiding
     * one would put the panel at odds with the related list beside it. unitNames is a
     * SENTENCE about that ledger, and SO-15095 in this org carries 64 rows for one
     * person on one unit - so before MSC-084 that row read "On WY-01" sixty-six times.
     */
    @isTest(SeeAllData=true)
    static void testAUnitIsNamedOnceHoweverManyRowsSayIt() {
        Id orderId = orderWithDuplicateRowsForOnePerson();
        /* 2.0 - the org's own duplicate-row fixture (one order carried 64 rows on
           20 Aug 2026) has since been cleaned up, so the malformed state is seeded
           here instead: two rows for one person in ONE insert, which slips MODON's
           duplicate check because it only queries committed rows. If their trigger
           ever closes that door too, the state this test defends against can no
           longer exist and the test retires with it - so it returns, not fails. */
        if (orderId == null) {
            SalesOrder__c seedOrder = openOrderWithNoOwners();
            if (seedOrder == null) {
                return;
            }
            Account dup = newPerson('DUPROW', 'Resident');
            try {
                insert new List<JointOwner__c>{
                    new JointOwner__c(
                        JointOwnerAccount__c = dup.Id, SalesOrder__c = seedOrder.Id,
                        OwnershipPercentage__c = 5,
                        RelationshipType__c = 'Joint Owner P-P',
                        RelationshipSubType__c = 'Spouse'),
                    new JointOwner__c(
                        JointOwnerAccount__c = dup.Id, SalesOrder__c = seedOrder.Id,
                        OwnershipPercentage__c = 5,
                        RelationshipType__c = 'Joint Owner P-P',
                        RelationshipSubType__c = 'Spouse')
                };
                orderId = seedOrder.Id;
            } catch (Exception e) {
                return; // the org now forbids creating the state; nothing to defend
            }
        }
        System.assert(orderId != null,
            'This org has no order carrying two rows for one person, so the repetition '
            + 'under test cannot be reached.');
        SalesOrder__c so = [
            SELECT Id, Opportunity__c FROM SalesOrder__c WHERE Id = :orderId LIMIT 1
        ];

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        Boolean exercised = false;
        for (SalesConsoleJointOwnerService.PartyDTO p : dto.parties) {
            Set<String> distinct = new Set<String>(p.unitNames);
            System.assertEquals(distinct.size(), p.unitNames.size(),
                p.name + ' has the same unit listed more than once: ' + p.unitNames);
            System.assert(p.unitNames.size() <= dto.units.size(),
                p.name + ' is on more units than the booking has: '
                + p.unitNames.size() + ' of ' + dto.units.size());
            if (p.holdings.size() > p.unitNames.size()) {
                exercised = true;
            }
        }
        System.assert(exercised,
            'The chosen order carried no party with more rows than units, so this test '
            + 'proved nothing. It must be run against the duplicate-row record.');
    }

    /**
     * ON ALL UNITS COUNTS UNITS, NOT ROWS - the same rows-not-people mistake this
     * file's own module has now corrected three times. Two duplicate rows on a
     * two-unit basket read as "on all 2 units" about somebody who is on one.
     */
    @isTest(SeeAllData=true)
    static void testOnAllUnitsCountsUnitsAndNotRows() {
        List<SalesOrder__c> basket = openBasket();
        System.assert(basket != null && basket.size() >= 2,
            'No open multi-unit booking with no owners on it.');
        Account person = newPerson('ONEUNIT', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.addOwner(req(basket[0], person.Id, 20));
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(basket[0].Opportunity__c, basket[0].Id);
        Test.stopTest();

        SalesConsoleJointOwnerService.PartyDTO p = partyFor(dto, person.Id);
        System.assertNotEquals(null, p, 'The person just added must be on the panel.');
        System.assertEquals(1, p.holdings.size(), 'One unit was targeted, so one row.');
        System.assertEquals(1, p.unitNames.size(), 'And one unit is named.');
        System.assertEquals(false, p.onAllUnits,
            'They are on 1 of ' + dto.units.size() + ' units, so the row must not say '
            + 'they are on all of them - that is the sentence a rep reads instead of '
            + 'checking, and it is how a unit ends up with nobody on it.');
    }

    /**
     * THE TAB'S BADGE AND THE PANEL UNDER IT ARE ONE NUMBER.
     *
     * partyCount exists so the My Bookings detail can label its Owners tab without
     * opening the panel, and it asks getOwners rather than counting for itself. A badge
     * reading 3 above a list of 2 is worse than no badge, and there are four separate
     * ways a cheaper count could have disagreed: a company-account buyer, a booking
     * whose every unit is dead, a person recorded twice, and rows on dead units.
     */
    @isTest(SeeAllData=true)
    static void testThePartyCountIsThePanelsOwnCount() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('COUNT', 'Resident');

        Test.startTest();
        Integer before = SalesConsoleJointOwnerService.partyCount(so.Opportunity__c);
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 20));
        Integer after = SalesConsoleJointOwnerService.partyCount(so.Opportunity__c);
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        System.assertEquals(1, before,
            'A booking with no joint owner is one person: the primary owner, who is a '
            + 'party on this panel and not a heading above it.');
        System.assertEquals(2, after, 'And two once somebody has been added.');
        System.assertEquals(dto.parties.size(), after,
            'The badge and the list it labels must be the same number.');
    }

    /** Nothing to count is zero, not a guess and not a crash. */
    @isTest
    static void testThePartyCountOfNothingIsZero() {
        Account buyer = newPerson('NOCOUNT', 'Resident');
        Opportunity opp = opportunityFor(buyer);

        Test.startTest();
        Integer none = SalesConsoleJointOwnerService.partyCount(null);
        Integer noUnit = SalesConsoleJointOwnerService.partyCount(opp.Id);
        Test.stopTest();

        System.assertEquals(0, none, 'No booking selected counts nobody.');
        System.assertEquals(0, noUnit,
            'And neither does a booking with no confirmed unit - the panel shows no '
            + 'parties there either, so a badge of 1 would label an empty list.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // MSC-085 · phase 6: proving MODON still works
    //
    // The only question this phase has to answer about the flattened fields is
    // whether MODON's own trigger writes them the same way for a row the console
    // created as for one a rep typed into the related list. Everything downstream
    // that reads JO1__c..JO6__c - portal onboarding, the Statement of Account, the
    // letters, the reporting classes - depends on that and on nothing else we do,
    // because §3.3 forbids us from writing those fields ourselves.
    // ══════════════════════════════════════════════════════════════════════

    /**
     * THREE OWNERS, THREE DIFFERENT SHARES, AND EVERY SHARE ON THE RIGHT PERSON.
     *
     * §10.1 row 3 asks for exactly this shape, and T4 is why: `updateJO` pairs an
     * `ownerList` built from a **Set<Id>** - whose iteration order Apex does not
     * guarantee - with an `ownershipList` built from a **List** in SOQL order. Two
     * owners cannot prove the pairing, because a swap and a correct answer look the
     * same when the shares are equal and there is a 50% chance of passing when they
     * are not. Three distinct shares can.
     *
     * The shares are 20 / 25 / 30 and are added in an order that is NOT the order the
     * trigger sorts them into (it sorts ascending), so a pass means the trigger really
     * did the sorting rather than the rows happening to arrive tidily.
     *
     * PROVED IN PREPROD FIRST, WHERE THE FAILURE IS REAL: of 208 orders there carrying
     * two or more flattened joint owners, 197 pair correctly, one (SO-01730) has two
     * people's shares crossed, and ten carry a person with no share at all. This test
     * is what says the console is not adding to that number.
     */
    @isTest(SeeAllData=true)
    static void testThreeOwnersAtThreeSharesFlattenOntoTheRightPeople() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');

        Account low  = newPerson('T4LOW',  'Resident');
        Account mid  = newPerson('T4MID',  'Resident');
        Account high = newPerson('T4HIGH', 'Resident');

        Test.startTest();
        /* Deliberately not in share order, and not in the order the trigger will
           flatten them into. 30/15/20 rather than the original 30/20/25: MODON's
           24 Aug primacy rule requires the buyer to keep the largest share, and
           these three leave them 35. The pairing under test is unchanged. */
        SalesConsoleJointOwnerService.addOwner(req(so, high.Id, 30));
        SalesConsoleJointOwnerService.addOwner(req(so, low.Id,  15));
        SalesConsoleJointOwnerService.addOwner(req(so, mid.Id,  20));
        Test.stopTest();

        /* What the records actually say, read back rather than assumed. */
        Map<Id, Decimal> shareByContact = new Map<Id, Decimal>();
        Map<Id, String>  nameByContact  = new Map<Id, String>();
        for (JointOwner__c jo : [
            SELECT JointOwnerAccount__r.PersonContactId, JointOwnerAccount__r.Name,
                   OwnershipPercentage__c
            FROM JointOwner__c WHERE SalesOrder__c = :so.Id
        ]) {
            shareByContact.put(jo.JointOwnerAccount__r.PersonContactId,
                               jo.OwnershipPercentage__c);
            nameByContact.put(jo.JointOwnerAccount__r.PersonContactId,
                              jo.JointOwnerAccount__r.Name);
        }
        System.assertEquals(3, shareByContact.size(),
            'Three people were added to one unit, so three rows must exist.');

        SalesOrder__c flat = [
            SELECT JO1__c, JO1_Ownership__c, JO2__c, JO2_Ownership__c,
                   JO3__c, JO3_Ownership__c, JO4__c, JO4_Ownership__c
            FROM SalesOrder__c WHERE Id = :so.Id
        ];

        /* WE NEVER WROTE THESE. If they are filled, MODON's trigger filled them from
           rows the console created - which is the whole claim phase 6 exists to test. */
        System.assertNotEquals(null, flat.JO1__c,
            'MODON\'s JointOwnerTriggerHelper.updateJO must flatten a console-created '
            + 'row exactly as it flattens one typed into the related list. Nothing here '
            + 'writes JO1__c - see section 3.3 of the implementation plan.');

        List<Id> contacts = new List<Id>{ flat.JO1__c, flat.JO2__c, flat.JO3__c };
        List<Decimal> shares = new List<Decimal>{
            flat.JO1_Ownership__c, flat.JO2_Ownership__c, flat.JO3_Ownership__c };

        Set<Id> seen = new Set<Id>();
        for (Integer i = 0; i < 3; i++) {
            Id c = contacts[i];
            System.assertNotEquals(null, c, 'JO' + (i + 1) + '__c is empty, but three '
                + 'people were added.');
            System.assert(shareByContact.containsKey(c),
                'JO' + (i + 1) + '__c names somebody who is not a joint owner on this unit.');
            System.assert(seen.add(c), 'The same person is flattened into two slots.');
            System.assertEquals(shareByContact.get(c), shares[i],
                'T4 - JO' + (i + 1) + '_Ownership__c carries the wrong person\'s share. '
                + 'That slot names ' + nameByContact.get(c) + ', who holds '
                + shareByContact.get(c) + '%, and the flattened share reads '
                + shares[i] + '%. This is the pairing SO-01730 in PREPROD gets wrong.');
        }
        System.assertEquals(null, flat.JO4__c,
            'Three were added, so the fourth slot must stay empty.');
    }

    /**
     * THE 100% CEILING WE ACCEPT IS A CEILING MODON ACCEPTS.
     *
     * §5.3's note on G6: a record we allow through must be one their trigger allows
     * through, because a disagreement in that direction surfaces as THEIR message on
     * the wrong record (T3). 99 is the largest total our guard permits, so 99 is the
     * number that has to survive `checkOwnershipPercentage`.
     */
    @isTest(SeeAllData=true)
    static void testTheMostWeAllowIsStillLessThanModonRefuses() {
        /* 2.0 - REWRITTEN FOR MODON'S 24 AUG RULE, not for MSC-180. Their
           JointOwnerTriggerHelper (changed in the org by MODON, 24 Aug 2026 -
           the repo copy is STALE and must not be deployed over it) now refuses any
           row that would leave the primary owner holding less than a joint owner.
           50 + 49 died with that: the second row leaves the buyer 1%. Two at 33 is
           the same claim this test always made - our guard permits what their rule
           permits - inside the new ceiling: the buyer keeps 34. */
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account a = newPerson('CEILA', 'Resident');
        Account b = newPerson('CEILB', 'Resident');

        Test.startTest();
        SalesConsoleJointOwnerService.addOwner(req(so, a.Id, 33));
        SalesConsoleJointOwnerService.addOwner(req(so, b.Id, 33));
        Test.stopTest();

        System.assertEquals(2, [
            SELECT COUNT() FROM JointOwner__c WHERE SalesOrder__c = :so.Id
        ], 'Two joint owners at 33% leave the primary owner 34% - the largest share, '
         + 'so MODON\'s primacy rule and our remainder guard both permit it and both '
         + 'rows must exist.');
    }

    /** Every door answers rather than throwing on nothing. */
    @isTest
    static void testSendVerificationRefusesNothingGracefully() {
        Test.startTest();
        String noPerson;
        try {
            SalesConsoleJointOwnerService.sendVerification(null, null, null);
        } catch (Exception e) {
            noPerson = e.getMessage();
        }
        System.assertNotEquals(null, noPerson, 'No person selected is a refusal, not a crash.');

        String noBooking;
        try {
            SalesConsoleJointOwnerService.sendVerification(
                null, null, UserInfo.getUserId());
        } catch (Exception e) {
            noBooking = e.getMessage();
        }
        Test.stopTest();
        System.assertNotEquals(null, noBooking, 'And neither is a missing booking.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // MSC-091 · once the link is out, the details stop moving
    // ══════════════════════════════════════════════════════════════════════

    /**
     * THE WRITE REFUSES, NOT JUST THE BUTTON.
     *
     * The row withholds Edit once a verification link has gone out, but a withheld
     * button is a hint: updateOwner is a public endpoint and a tab opened before the
     * link was sent still carries a live Edit. This is the rule, and it is asserted on
     * the write rather than on the panel that draws it.
     *
     * The refusal has to name the person and say what happened - a rep who is told
     * "not allowed" goes and asks somebody, and a rep who is told the link is already
     * out knows to resend rather than to edit.
     */
    @isTest(SeeAllData=true)
    static void testAPersonWhoseLinkIsOutCanNoLongerBeEdited() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('SENTEDIT', 'Resident');
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));

        /* The link going out, as MODON's own Flow records it. Nothing about compliance
           is touched: this is the send stamp and nothing else. */
        update new Account(Id = person.Id, KYC_Send_Date_Time__c = System.now());

        SalesConsoleJointOwnerService.UpdateOwnerInput u =
            new SalesConsoleJointOwnerService.UpdateOwnerInput();
        u.opportunityId       = so.Opportunity__c;
        u.salesOrderId        = so.Id;
        u.accountId           = person.Id;
        u.targetOrderIds      = new List<Id>{ so.Id };
        u.share               = 45;
        u.relationshipType    = 'Partner';
        u.relationshipSubType = 'Friend';

        String refusal;
        Test.startTest();
        try {
            SalesConsoleJointOwnerService.updateOwner(u);
        } catch (Exception e) {
            refusal = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, refusal,
            'A joint owner whose identity verification is already under way must not '
            + 'be editable from the console.');
        System.assert(refusal.contains(person.Name),
            'The refusal names the person it is about. Got: ' + refusal);
        System.assert(refusal.contains('verification link'),
            'And says what happened, so the rep resends rather than trying to edit '
            + 'again. Got: ' + refusal);

        JointOwner__c jo = [
            SELECT OwnershipPercentage__c FROM JointOwner__c
            WHERE SalesOrder__c = :so.Id AND JointOwnerAccount__c = :person.Id
        ];
        System.assertEquals(30, jo.OwnershipPercentage__c,
            'And nothing moved. A refusal that half-writes is worse than one that '
            + 'does not refuse at all.');
    }

    /**
     * The panel says so before the rep presses anything.
     *
     * canEdit is the server's answer and it is the SAME answer updateOwner gives on the
     * write, so the row and the gate can never disagree about one person.
     */
    @isTest(SeeAllData=true)
    static void testThePanelClosesTheRowTheMomentTheLinkGoesOut() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('SENTROW', 'Resident');
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 25));

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO before =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        update new Account(Id = person.Id, KYC_Send_Date_Time__c = System.now());
        SalesConsoleJointOwnerService.OwnersDTO after =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        SalesConsoleJointOwnerService.PartyDTO wasOpen = partyFor(before, person.Id);
        SalesConsoleJointOwnerService.PartyDTO nowShut = partyFor(after, person.Id);

        System.assertNotEquals(null, wasOpen, 'The joint owner is on the panel.');
        System.assertEquals(true, wasOpen.canEdit,
            'Before any link goes out their row is editable - this is the rule '
            + 'arriving, not a row that was always shut.');
        System.assertNotEquals(null, nowShut, 'They are still on the panel afterwards.');
        System.assertEquals(false, nowShut.canEdit,
            'And closed the moment the link is out.');
        System.assertNotEquals(null, nowShut.editBlockedReason,
            'A row that cannot be changed says why. Silence sends the rep to ask '
            + 'somebody.');
    }

    /** The primary owner is never editable here, and for a different reason. */
    @isTest(SeeAllData=true)
    static void testThePrimaryOwnersRowIsNeverAnEditDoor() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        for (SalesConsoleJointOwnerService.PartyDTO p : dto.parties) {
            if (p.isPrimary == true) {
                System.assertEquals(false, p.canEdit,
                    'Their Ownership % is 100 less the others and is not a settable '
                    + 'field, so their row must never open the joint owner drawer.');
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // 2.0 - MSC-180. companies, on both sides of the table
    // ══════════════════════════════════════════════════════════════════════

    private static Id orgRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount'
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /** A company already on file, licence in the field the search reads first. */
    private static Account newCompany(String name, String licence) {
        Account a = new Account(
            Name = name,
            RecordTypeId = orgRecordTypeId(),
            TradeLicenseNumber__c = licence
        );
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        Database.SaveResult sr = Database.insert(a, o);
        System.assert(sr.isSuccess(),
            'The test could not create a company candidate: '
            + (sr.getErrors().isEmpty() ? '(no error given)' : sr.getErrors()[0].getMessage()));
        return [
            SELECT Id, Name, IsPersonAccount, Is_Merged__c
            FROM Account WHERE Id = :a.Id
        ];
    }

    /** An add request for a NEW company: name + licence, commercial relationship. */
    private static SalesConsoleJointOwnerService.AddOwnerInput companyReq(
        SalesOrder__c so, String name, String licence
    ) {
        SalesConsoleJointOwnerService.AddOwnerInput r = req(so, null, 5);
        r.isCompany           = true;
        r.companyName         = name;
        r.tradeLicence        = licence;
        r.relationshipType    = 'Partner';
        r.relationshipSubType = 'Spouse';
        return r;
    }

    /** A live corporate booking, by the same rules openOrderWithNoOwners applies. */
    private static SalesOrder__c openCorporateOrder() {
        for (SalesOrder__c so : [
            SELECT Id, Name, Opportunity__c, Status__c, SPAStatus__c, Source_Entity__c,
                   Unit__c, Unit__r.Name
            FROM SalesOrder__c
            WHERE Opportunity__r.Account.IsPersonAccount = false
            /* 1.x - and it has to BE a booking. `IsPersonAccount = false` also matches an order
               whose Opportunity is null, because the traversal is null rather than false: that is
               how SO-15491, an orphan with no opportunity and no unit, became the newest
               "corporate" order and the panel answered "No booking selected". */
            AND Opportunity__c != null
            AND Unit__c != null
            AND SPA_Send_Date_for_Signature__c = null
            AND (SPAStatus__c = null OR SPAStatus__c = 'SPA Not Generated')
            ORDER BY CreatedDate DESC
            LIMIT 60
        ]) {
            if (!inAny(DEAD, so.Status__c)
                    && !inAny(SPA_OUT, so.Status__c)
                    && so.Source_Entity__c != EGYPT) {
                return so;
            }
        }
        return null;
    }

    /** The corporate gate is open: the panel describes a real corporate booking. */
    @isTest(SeeAllData=true)
    static void testCorporateBookingDescribes() {
        SalesOrder__c so = openCorporateOrder();
        System.assert(so != null,
            'No live corporate Sales Order in this org - the corporate opening '
            + 'cannot be proved without one.');

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto =
            SalesConsoleJointOwnerService.getOwners(so.Opportunity__c, so.Id);
        Test.stopTest();

        System.assertEquals(true, dto.available,
            'A live corporate booking must be describable now. Blocked: ' + dto.blockedReason);
        System.assertEquals(true, dto.buyerIsCompany, 'The DTO says what the buyer is.');
        System.assert(!dto.parties.isEmpty(), 'The company itself is the first party.');
        System.assertEquals(true, dto.parties[0].isPrimary, 'The buyer still comes first.');
        System.assertEquals(true, dto.parties[0].isCompany,
            'And its row is marked as the company it is.');
        System.assertEquals(false, dto.parties[0].canSendVerification,
            'No verification link exists for a company - 1.8\'s truth, kept.');
    }

    /**
     * The company account, written field for field the way companyUpdate writes one:
     * licence into all three licence fields, name into both name fields, the customer
     * record type - and the row under the booking, marked as a company on the DTO.
     */
    @isTest(SeeAllData=true)
    static void testCompanyOwnerCreateWritesTheExactAccount() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners to write onto.');
        String licence = 'JOTL-' + so.Id;

        Test.startTest();
        SalesConsoleJointOwnerService.OwnersDTO dto = SalesConsoleJointOwnerService.addOwner(
            companyReq(so, 'JOT Company Ltd', licence));
        Test.stopTest();

        List<Account> made = [
            SELECT Id, Name, IsPersonAccount, RecordType.DeveloperName,
                   Company_Name_as_per_Trade_License__c,
                   UnifiedNumber__c, TradeLicenseNumber__c, Trade_License_Number__c
            FROM Account WHERE TradeLicenseNumber__c = :licence
        ];
        System.assertEquals(1, made.size(), 'Exactly one company account is created.');
        Account a = made[0];
        System.assertEquals(false, a.IsPersonAccount, 'A business account, not a person.');
        System.assertEquals('OrganizationAccount', a.RecordType.DeveloperName,
            'The org\'s customer record type - never the buyer\'s, never blank.');
        System.assertEquals('JOT Company Ltd', a.Company_Name_as_per_Trade_License__c,
            'The name lands in both fields companyUpdate writes.');
        System.assertEquals(licence, a.UnifiedNumber__c, 'The field Passfort sends.');
        System.assertEquals(licence, a.Trade_License_Number__c, 'And the third licence field.');

        System.assertEquals(1, [
            SELECT COUNT() FROM JointOwner__c
            WHERE SalesOrder__c = :so.Id AND JointOwnerAccount__c = :a.Id
        ], 'The junction row exists.');

        Boolean found = false;
        for (SalesConsoleJointOwnerService.PartyDTO p : dto.parties) {
            if (p.accountId == a.Id) {
                found = true;
                System.assertEquals(true, p.isCompany, 'The row says what it is.');
                System.assertEquals(false, p.canSendVerification,
                    'No link for a company; the chip explains instead.');
                System.assert(String.isNotBlank(p.verificationBlockedReason),
                    'The reason is stated, not implied.');
            }
        }
        System.assert(found, 'The new company is a party of the answer.');
    }

    /** A second add under the same licence resolves to the SAME account and is refused
        as a duplicate - the Account-keyed fence, which MODON's trigger does not carry
        for companies. */
    @isTest(SeeAllData=true)
    static void testCompanyDuplicateIsRefused() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners to write onto.');
        String licence = 'JOTD-' + so.Id;

        SalesConsoleJointOwnerService.addOwner(companyReq(so, 'JOT Dup Co', licence));
        String refusal = refusalFrom(companyReq(so, 'JOT Dup Co Again', licence));

        System.assert(refusal != null && refusal.containsIgnoreCase('already'),
            'The same licence is the same company, and one company sits on a unit '
            + 'once. Got: ' + refusal);
    }

    /** Kinship cannot describe a company. The server refuses what the list no longer
        offers, because addOwner is a public endpoint. */
    @isTest(SeeAllData=true)
    static void testCompanyRelationshipMustBeCommercial() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners to write onto.');

        SalesConsoleJointOwnerService.AddOwnerInput r =
            companyReq(so, 'JOT Kin Co', 'JOTK-' + so.Id);
        r.relationshipType = 'Joint Owner P-P';
        String refusal = refusalFrom(r);

        System.assert(
            refusal != null && refusal.contains('Partner or Third Party'),
            'The refusal names the two types that fit. Got: ' + refusal
        );
    }

    /** The licence search finds a company already on file - as a result, not a
        refusal - and the found card can say what kind of account it is. */
    @isTest
    static void testFindPersonFindsACompanyByLicence() {
        Account buyer = newPerson('COFIND', 'Resident');
        Opportunity o = opportunityFor(buyer);
        String licence = 'JOTF-' + o.Id;
        Account co = newCompany('JOT Find Co', licence);

        Test.startTest();
        List<SalesConsoleJointOwnerService.PersonDTO> found =
            SalesConsoleJointOwnerService.findPerson(o.Id, licence);
        Test.stopTest();

        System.assertEquals(1, found.size(), 'The licence names one company.');
        System.assertEquals(co.Id, found[0].accountId, 'And it is that company.');
        System.assertEquals(true, found[0].isCompany, 'Said, so the card can say it.');
        System.assertEquals(null, found[0].blockedReason,
            'A company match is usable now, not a dead end.');
    }

    /** A crafted accountId naming a broker agency is refused: the search can never
        return one, so the endpoint must refuse one on its own. */
    @isTest(SeeAllData=true)
    static void testBrokerAgencyCannotBeAJointOwner() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners to write onto.');
        List<RecordType> brokerRt = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = 'Broker_Agency'
            LIMIT 1
        ];
        if (brokerRt.isEmpty()) {
            return; // this org cannot express the case
        }
        Account agency = new Account(
            Name = 'JOT Broker Agency', RecordTypeId = brokerRt[0].Id
        );
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        Database.insert(agency, o);

        SalesConsoleJointOwnerService.AddOwnerInput r = req(so, agency.Id, 5);
        r.relationshipType = 'Partner';
        String refusal = refusalFrom(r);

        System.assert(refusal != null && refusal.containsIgnoreCase('not a customer'),
            'A broker agency is not a customer and never a co-owner. Got: ' + refusal);
    }

    /** A company's edit is share and relationship - and the update path holds the
        same commercial-relationship fence the add does. */
    @isTest(SeeAllData=true)
    static void testCompanyEditMovesTheShare() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners to write onto.');
        String licence = 'JOTE-' + so.Id;
        SalesConsoleJointOwnerService.addOwner(companyReq(so, 'JOT Edit Co', licence));
        Id companyId = [
            SELECT Id FROM Account WHERE TradeLicenseNumber__c = :licence LIMIT 1
        ].Id;

        SalesConsoleJointOwnerService.UpdateOwnerInput u =
            new SalesConsoleJointOwnerService.UpdateOwnerInput();
        u.opportunityId       = so.Opportunity__c;
        u.salesOrderId        = so.Id;
        u.accountId           = companyId;
        u.share               = 12;
        u.relationshipType    = 'Third Party';
        u.relationshipSubType = 'Spouse';

        Test.startTest();
        SalesConsoleJointOwnerService.updateOwner(u);
        Test.stopTest();

        System.assertEquals(12, [
            SELECT OwnershipPercentage__c FROM JointOwner__c
            WHERE SalesOrder__c = :so.Id AND JointOwnerAccount__c = :companyId
            LIMIT 1
        ].OwnershipPercentage__c, 'The share moved; nothing personal was asked for.');
    }


    // ══════════════════════════════════════════════════════════════════════
    // 2.1: MODON's joint owner KYC check
    // ══════════════════════════════════════════════════════════════════════

    /** The card carries MODON's own answer: ready with the check off, its message with it on. */
    @isTest(SeeAllData=true)
    static void testPersonCardCarriesModonKycCheck() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('KYCCARD', 'Resident');

        SalesConsoleJointOwnerService.PersonDTO bypassed =
            SalesConsoleJointOwnerService.checkPerson(so.Opportunity__c, so.Id, person.Id);
        System.assertEquals(true, bypassed.kycReady, 'MODON\'s check is bypassed in tests by default.');

        JointOwnerTriggerHelper.bypassKYCCheck = false;
        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO checked =
            SalesConsoleJointOwnerService.checkPerson(so.Opportunity__c, so.Id, person.Id);
        Test.stopTest();
        System.assertEquals(false, checked.kycReady, 'A new person has no KYC.');
        System.assert(checked.kycIssue != null && checked.kycIssue.containsIgnoreCase('KYC is not complete'),
            'MODON\'s own words. Got: ' + checked.kycIssue);
        System.assertEquals('NOT_SENT', checked.kycStatus);
        System.assertEquals(false, checked.canSendKyc, 'No email, mobile or nationality yet.');
        System.assertNotEquals(null, checked.kycBlockedReason, 'So the card says what is missing.');
    }

    /** With MODON's check on, an add without KYC is refused in MODON's words and nothing is written. */
    @isTest(SeeAllData=true)
    static void testAddWithoutKycIsRefusedByModon() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('KYCADD', 'Resident');

        JointOwnerTriggerHelper.bypassKYCCheck = false;
        Test.startTest();
        String msg = refusalFrom(req(so, person.Id, 20));
        Test.stopTest();
        System.assert(msg != null && msg.containsIgnoreCase('KYC is not complete'), 'Got: ' + msg);
        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id]);
    }

    /** A person not yet on the booking can be sent a KYC link; the unit is stamped first. */
    @isTest(SeeAllData=true)
    static void testCandidateKycLinkStampsTheUnit() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('KYCLINK', 'Resident');
        giveContactDetails(person.Id, 'jotest.kyclink@example.com', '+971500000011');

        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO p =
            SalesConsoleJointOwnerService.sendCandidateVerification(so.Opportunity__c, so.Id, person.Id);
        Test.stopTest();
        System.assertEquals('SENDING', p.kycStatus);
        System.assertEquals(false, p.canSendKyc, 'No second send while the first is going out.');
        Account after = [SELECT KYCUnitName__pc FROM Account WHERE Id = :person.Id];
        System.assertEquals(so.Unit__r.Name, after.KYCUnitName__pc, 'The form names the unit.');
        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id],
            'Sending a link adds nobody.');
    }

    /** Someone already on the booking is sent their link from their row, not from here. */
    @isTest(SeeAllData=true)
    static void testCandidateKycLinkRefusesSomeoneAlreadyOnTheBooking() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('KYCON', 'Resident');
        giveContactDetails(person.Id, 'jotest.kycon@example.com', '+971500000012');
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 20));

        String msg;
        Test.startTest();
        try {
            SalesConsoleJointOwnerService.sendCandidateVerification(so.Opportunity__c, so.Id, person.Id);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();
        System.assert(msg != null && msg.containsIgnoreCase('already on this booking'), 'Got: ' + msg);
    }

    /** createPerson makes the account and adds nobody. */
    @isTest(SeeAllData=true)
    static void testCreatePersonDoesNotAddThem() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        SalesConsoleJointOwnerService.AddOwnerInput r = req(so, null, null);
        r.firstName      = 'JOTest';
        r.lastName       = 'CreateOnly';
        r.residentStatus = 'Non-Resident';
        r.passportNumber = 'JOTCRE01';
        r.eidNumber      = 'JOTCRE01';

        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO p = SalesConsoleJointOwnerService.createPerson(r);
        Test.stopTest();
        System.assertNotEquals(null, p.accountId, 'The person exists.');
        System.assertEquals(false, p.alreadyOnThisBooking);
        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :p.accountId],
            'Nobody was added.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // 2.2: the buyer's match before a new person is created
    // ══════════════════════════════════════════════════════════════════════

    /** A new person as the drawer sends one: the typed number as both documents. */
    private static SalesConsoleJointOwnerService.AddOwnerInput newPersonReq(
        SalesOrder__c so, String lastName, String doc, String email
    ) {
        SalesConsoleJointOwnerService.AddOwnerInput r = req(so, null, null);
        r.firstName      = 'JOTest';
        r.lastName       = lastName;
        r.residentStatus = 'Non-Resident';
        r.eidNumber      = doc;
        r.passportNumber = doc;
        r.email          = email;
        return r;
    }

    private static SalesConsoleJointOwnerService.MatchDTO matchFor(
        SalesConsoleJointOwnerService.PersonDTO p, Id accountId
    ) {
        if (p == null || p.matches == null) {
            return null;
        }
        for (SalesConsoleJointOwnerService.MatchDTO m : p.matches) {
            if (m.accountId == accountId) {
                return m;
            }
        }
        return null;
    }

    /** A document match: nothing is created, and the existing customer comes back to choose. */
    @isTest(SeeAllData=true)
    static void testCreatePersonStopsOnADocumentMatch() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account existing = newPerson('MDOC', 'Resident');   // EIDNumber__pc JOTMDOC

        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO p =
            SalesConsoleJointOwnerService.createPerson(newPersonReq(so, 'MatchDocNew', 'JOTMDOC', null));
        Test.stopTest();

        System.assertEquals(null, p.accountId, 'Nothing was created.');
        SalesConsoleJointOwnerService.MatchDTO m = matchFor(p, existing.Id);
        System.assertNotEquals(null, m, 'The existing customer is offered.');
        System.assertEquals('eid', m.matchedOn);
        System.assertEquals(null, m.blockedReason);
        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE LastName = 'MatchDocNew']);
        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :existing.Id]);
    }

    /** An email match with no document match: the same chooser, as for a buyer. */
    @isTest(SeeAllData=true)
    static void testCreatePersonStopsOnAnEmailMatch() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account existing = newPerson('MEML', 'Resident');
        giveContactDetails(existing.Id, 'jotest.meml.2809@example.com', '+971500002809');

        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO p = SalesConsoleJointOwnerService.createPerson(
            newPersonReq(so, 'MatchEmailNew', 'JOTNOSUCH2809', 'jotest.meml.2809@example.com'));
        Test.stopTest();

        System.assertEquals(null, p.accountId, 'Nothing was created.');
        SalesConsoleJointOwnerService.MatchDTO m = matchFor(p, existing.Id);
        System.assertNotEquals(null, m, 'The customer holding the email is offered.');
        System.assertEquals('email', m.matchedOn);
        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE LastName = 'MatchEmailNew']);
    }

    /** Someone already on the booking is listed but marked, so they cannot be chosen twice. */
    @isTest(SeeAllData=true)
    static void testAMatchAlreadyOnTheBookingIsMarked() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account existing = newPerson('MON', 'Resident');
        SalesConsoleJointOwnerService.addOwner(req(so, existing.Id, 20));

        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO p =
            SalesConsoleJointOwnerService.createPerson(newPersonReq(so, 'MatchOnNew', 'JOTMON', null));
        Test.stopTest();

        SalesConsoleJointOwnerService.MatchDTO m = matchFor(p, existing.Id);
        System.assertNotEquals(null, m);
        System.assert(m.blockedReason != null && m.blockedReason.containsIgnoreCase('already on this booking'),
            'Got: ' + m.blockedReason);
    }

    /** Create anyway, with the switch off: MODON's sentence, and nobody is created. */
    @isTest(SeeAllData=true)
    static void testCreateAnywayIsRefusedWhileTheSwitchIsOff() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        newPerson('MOFF', 'Resident');
        SalesConsoleJointOwnerService.AddOwnerInput r = newPersonReq(so, 'MatchOffNew', 'JOTMOFF', null);
        r.createDespiteMatch = true;
        AurelixNewCustomerSwitch.switchOverride = false;

        String msg;
        Test.startTest();
        try {
            SalesConsoleJointOwnerService.createPerson(r);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(SalesConsoleLeadController.MATCH_MUST_BE_CHOSEN, msg);
        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE LastName = 'MatchOffNew']);
    }

    /** Create anyway, with the switch on: a new person despite the match. */
    @isTest(SeeAllData=true)
    static void testCreateAnywayWithTheSwitchOnCreatesTheNewPerson() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account existing = newPerson('MONS', 'Resident');
        SalesConsoleJointOwnerService.AddOwnerInput r = newPersonReq(so, 'MatchOnSwitchNew', 'JOTMONS', null);
        r.createDespiteMatch = true;
        AurelixNewCustomerSwitch.switchOverride = true;

        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO p = SalesConsoleJointOwnerService.createPerson(r);
        Test.stopTest();

        System.assertNotEquals(null, p.accountId, 'Created.');
        System.assertNotEquals(existing.Id, p.accountId, 'A new person, not the match.');
        System.assertEquals(null, p.matches);
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE LastName = 'MatchOnSwitchNew']);
    }

    /** No match: the person is created directly, as before (no Lead). */
    @isTest(SeeAllData=true)
    static void testCreatePersonWithNoMatchCreatesThePerson() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        AurelixNewCustomerSwitch.switchOverride = false;

        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO p = SalesConsoleJointOwnerService.createPerson(
            newPersonReq(so, 'NoMatchNew', 'JOTNOMATCH2809', 'jotest.nomatch.2809@example.com'));
        Test.stopTest();

        System.assertNotEquals(null, p.accountId, 'The person exists.');
        System.assertEquals(null, p.matches);
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE LastName = 'NoMatchNew']);
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE LastName = 'NoMatchNew'], 'No Lead.');
    }

    /** addOwner with a new person who matches: refused, nothing written. */
    @isTest(SeeAllData=true)
    static void testAddOwnerRefusesANewPersonWhoMatches() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account existing = newPerson('MADD', 'Resident');
        SalesConsoleJointOwnerService.AddOwnerInput r = newPersonReq(so, 'MatchAddNew', 'JOTMADD', null);
        r.share = 20;

        Test.startTest();
        String msg = refusalFrom(r);
        Test.stopTest();

        System.assertEquals(SalesConsoleLeadController.MATCH_MUST_BE_CHOSEN, msg);
        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE LastName = 'MatchAddNew']);
        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE SalesOrder__c = :so.Id]);
    }

    // ══════════════════════════════════════════════════════════════════════
    // 2.2: the joint owner's manual KYC route
    // ══════════════════════════════════════════════════════════════════════

    /** A person the rep could add may use the route; the buyer and nobody may not. */
    @isTest(SeeAllData=true)
    static void testPartyProblemAllowsACandidateOnly() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('PTY1', 'Resident');
        Id buyerId = [SELECT AccountId FROM Opportunity WHERE Id = :so.Opportunity__c].AccountId;

        Test.startTest();
        String forPerson = SalesConsoleJointOwnerService.partyProblem(so.Opportunity__c, person.Id);
        String forBuyer  = SalesConsoleJointOwnerService.partyProblem(so.Opportunity__c, buyerId);
        String forNobody = SalesConsoleJointOwnerService.partyProblem(so.Opportunity__c, null);
        Test.stopTest();

        System.assertEquals(null, forPerson, 'A person who could be added.');
        System.assert(forBuyer != null && forBuyer.containsIgnoreCase('primary owner'), 'Got: ' + forBuyer);
        System.assertNotEquals(null, forNobody);
    }

    /** The checklist of someone not yet on the booking (they cannot be added before their KYC). */
    @isTest(SeeAllData=true)
    static void testAJointOwnersChecklistCoversSomeoneNotYetAdded() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('PTY2', 'Resident');

        Test.startTest();
        AurelixKycDocumentService.ChecklistDTO dto =
            AurelixKycDocumentService.getChecklist(so.Opportunity__c, person.Id);
        Test.stopTest();

        System.assertEquals(true, dto.available, 'Got: ' + dto.blockedReason);
        System.assertEquals(1, dto.groups.size());
        System.assertEquals(AurelixKycDocumentService.ROLE_OWNER, dto.groups[0].role);
        System.assertEquals(4, dto.groups[0].total, 'A resident needs the four documents.');
    }

    /** The evaluation and MODON's submission run on the joint owner's own Account. */
    @isTest(SeeAllData=true)
    static void testTheJointOwnersManualKycIsSubmittedOnTheirAccount() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('PTY3', 'Resident');

        AurelixManualKycService.ManualKycStateDTO st =
            AurelixManualKycService.evaluateParty(so.Opportunity__c, person.Id);
        System.assertEquals(null, st.blockedReason);
        System.assertEquals(person.Id, st.accountId, 'The upload and the request land on their Account.');
        System.assertEquals(person.Id, st.subjectId);
        System.assert(!st.reasonOptions.isEmpty(), 'MODON\'s reasons.');
        String reason = st.reasonOptions[0].value;

        Test.startTest();
        String msg = AurelixManualKycService.submitPartyManualKyc(
            so.Opportunity__c, person.Id, reason, 'JO manual KYC test', null);
        Test.stopTest();

        System.assertEquals('Submitted for manual KYC approval.', msg);
        Account after = [SELECT KYC_Manual_Reason__c, Manual_KYC_Comment__c FROM Account WHERE Id = :person.Id];
        System.assertEquals(reason, after.KYC_Manual_Reason__c, 'MODON\'s submitForApproval wrote it.');
        System.assertEquals('JO manual KYC test', after.Manual_KYC_Comment__c);
        System.assertEquals(0, [SELECT COUNT() FROM JointOwner__c WHERE JointOwnerAccount__c = :person.Id],
            'Nobody was added.');
    }

    /** An approved joint owner: Update KYC is offered on their Account; the buyer gets nothing here. */
    @isTest(SeeAllData=true)
    static void testAJointOwnersApprovalUnlocksUpdateKyc() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('PTY4', 'Resident');
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        Database.update(new Account(Id = person.Id, Manual_KYC_Approval__c = 'Approved'), o);
        Id buyerId = [SELECT AccountId FROM Opportunity WHERE Id = :so.Opportunity__c].AccountId;

        Test.startTest();
        AurelixManualKycService.ManualOutcomeDTO out =
            AurelixManualKycService.getPartyManualOutcome(so.Opportunity__c, person.Id);
        AurelixManualKycService.ApprovalTrailDTO trail =
            AurelixManualKycService.getPartyApprovalTrail(so.Opportunity__c, person.Id);
        AurelixManualKycService.ManualOutcomeDTO none =
            AurelixManualKycService.getPartyManualOutcome(so.Opportunity__c, buyerId);
        Test.stopTest();

        System.assertEquals(true, out.approved);
        System.assertEquals(true, out.canUpdateKyc);
        System.assertEquals(person.Id, out.accountId);
        System.assertEquals(person.Id, out.subjectId, 'Update KYC opens on their Account.');
        System.assertEquals(true, out.generationOffered, 'A person with a contact is offered Generate.');
        System.assertEquals(false, trail.live, 'No request is waiting.');
        System.assertEquals(null, none.accountId, 'The buyer is not a party of their own booking.');
    }

    /** Generate for a joint owner is refused with the gate's sentence while details are missing. */
    @isTest(SeeAllData=true)
    static void testAJointOwnersFormIsRefusedUntilTheGatePasses() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('PTY5', 'Resident');

        String msg;
        Test.startTest();
        try {
            AurelixManualKycService.requestPartyKycFormGeneration(so.Opportunity__c, person.Id);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, msg, 'A bare person cannot have a form yet.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // 2.3: Nationality and Resident Status are restricted picklists
    // ══════════════════════════════════════════════════════════════════════

    /** A nationality that is not on the list is refused before anything is written. */
    @isTest(SeeAllData=true)
    static void testCreatePersonRefusesANationalityOffTheList() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        SalesConsoleJointOwnerService.AddOwnerInput r =
            newPersonReq(so, 'NatOffList', 'JOTNATOFF2909', null);
        r.nationality = 'Emirati';

        String msg;
        Test.startTest();
        try {
            SalesConsoleJointOwnerService.createPerson(r);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(SalesConsoleJointOwnerService.NATIONALITY_NOT_LISTED, msg);
        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE LastName = 'NatOffList']);
    }

    /** A listed value typed in another case is written as the list spells it. */
    @isTest(SeeAllData=true)
    static void testCreatePersonWritesTheListSpelling() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        AurelixNewCustomerSwitch.switchOverride = false;
        SalesConsoleJointOwnerService.AddOwnerInput r =
            newPersonReq(so, 'NatListCase', 'JOTNATCASE2909', null);
        r.nationality    = '  united arab emirates ';
        r.residentStatus = 'non-resident';

        Test.startTest();
        SalesConsoleJointOwnerService.PersonDTO p = SalesConsoleJointOwnerService.createPerson(r);
        Test.stopTest();

        System.assertNotEquals(null, p.accountId, 'The person exists.');
        Account a = [SELECT Nationality__pc, UAE_Resident_Status__pc FROM Account WHERE Id = :p.accountId];
        System.assertEquals('United Arab Emirates', a.Nationality__pc);
        System.assertEquals('Non-Resident', a.UAE_Resident_Status__pc);
    }

    /** A Resident Status that is not on the list is refused. */
    @isTest(SeeAllData=true)
    static void testCreatePersonRefusesAResidencyOffTheList() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        SalesConsoleJointOwnerService.AddOwnerInput r =
            newPersonReq(so, 'ResOffList', 'JOTRESOFF2909', null);
        r.residentStatus = 'International';

        String msg;
        Test.startTest();
        try {
            SalesConsoleJointOwnerService.createPerson(r);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(SalesConsoleJointOwnerService.RESIDENCY_NOT_LISTED, msg);
        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE LastName = 'ResOffList']);
    }

    /** The edit fill refuses a nationality off the list and leaves the account as it was. */
    @isTest(SeeAllData=true)
    static void testUpdateRefusesANationalityOffTheList() {
        SalesOrder__c so = openOrderWithNoOwners();
        System.assert(so != null, 'No open Sales Order with no owners.');
        Account person = newPerson('VNATOFF', 'Resident');
        SalesConsoleJointOwnerService.addOwner(req(so, person.Id, 30));

        SalesConsoleJointOwnerService.UpdateOwnerInput u =
            new SalesConsoleJointOwnerService.UpdateOwnerInput();
        u.opportunityId       = so.Opportunity__c;
        u.salesOrderId        = so.Id;
        u.accountId           = person.Id;
        u.targetOrderIds      = new List<Id>{ so.Id };
        u.share               = 30;
        u.relationshipType    = 'Joint Owner P-P';
        u.relationshipSubType = 'Spouse';
        u.mobile              = '+971500002909';
        u.nationality         = 'Emirati';

        String msg;
        Test.startTest();
        try {
            SalesConsoleJointOwnerService.updateOwner(u);
        } catch (Exception e) {
            msg = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(SalesConsoleJointOwnerService.NATIONALITY_NOT_LISTED, msg);
        Account after = [SELECT PersonMobilePhone, Nationality__pc FROM Account WHERE Id = :person.Id];
        System.assertEquals(null, after.Nationality__pc, 'Nothing written.');
        System.assertEquals(null, after.PersonMobilePhone, 'Nor the mobile beside it.');
    }

    // ══════════════════════════════════════════════════════════════════════
    // 2.4 - every rep finds every customer, whoever owns the account
    // ══════════════════════════════════════════════════════════════════════

    /** A console user with no View All on Account (profile Sales Operation), made as the admin. */
    private static User repWithoutAccess(String alias) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Sales Operation' LIMIT 1];
            u = new User(
                Alias = alias, Email = alias + '@example.com', EmailEncodingKey = 'UTF-8',
                LastName = 'NoAccess' + alias, LanguageLocaleKey = 'en_US', LocaleSidKey = 'en_US',
                ProfileId = p.Id, TimeZoneSidKey = 'Asia/Dubai',
                Username = alias + '.' + Datetime.now().getTime() + '@example.com.scw'
            );
            insert u;
            for (PermissionSet ps : [
                SELECT Id FROM PermissionSet WHERE Name = 'Modon_Sales_Console' LIMIT 1
            ]) {
                insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
            }
        }
        return u;
    }

    @isTest
    static void testJointOwnerSearchFindsSomeoneTheRepCannotSee() {
        Account existing = newPerson('HIDDEN', 'Resident');
        User rep = repWithoutAccess('scwjoa1');
        System.assertEquals(false, [
            SELECT RecordId, HasReadAccess FROM UserRecordAccess
            WHERE UserId = :rep.Id AND RecordId = :existing.Id
        ].HasReadAccess, 'Precondition: this console user has no access to the person.');

        List<SalesConsoleJointOwnerService.PersonDTO> found;
        SalesConsoleJointOwnerService.PersonDTO checked;
        System.runAs(rep) {
            found = SalesConsoleJointOwnerService.findPerson(null, 'JOTHIDDEN');
            checked = SalesConsoleJointOwnerService.checkPerson(null, null, existing.Id);
        }
        System.assertEquals(1, found.size(), 'The document finds the person whoever owns them.');
        System.assertEquals(existing.Id, found[0].accountId);
        System.assertEquals(existing.Name, found[0].name, 'And their card is shown, not a blank one.');
        System.assertEquals(existing.Id, checked.accountId, 'Checking them again reads them too.');
    }

    @isTest
    static void testJointOwnerMatchListsSomeoneTheRepCannotSee() {
        Account existing = newPerson('HIDMATCH', 'Resident');
        User rep = repWithoutAccess('scwjoa2');

        /* createPerson's match, as the rep, with the drawer's one number as both documents */
        List<Account> matches;
        System.runAs(rep) {
            matches = SalesConsoleLeadController.matchPersonCandidates('JOTHIDMATCH', 'JOTHIDMATCH', null, null);
        }
        Boolean listed = false;
        for (Account a : matches) {
            if (a.Id == existing.Id) {
                listed = true;
            }
        }
        System.assert(listed, 'Create person meets the person the rep could not see, in the chooser.');
    }
}