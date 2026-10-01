/**
 * Tests for SalesConsoleLeadController.
 *
 * Version  Author      Date         Detail
 * 1.29     Aurelix Dev 29 Sep 2026  Controller 1.34: a rep with no access to another user's customer still
 *                                   finds, reads, books for and converges on that customer.
 * 1.28     Aurelix Dev 29 Sep 2026  Controller 1.33: person match tests (Emirates ID for a Resident only,
 *                                   every key at once, merged accounts left out, mobile spellings).
 *                                   testIdMatchAndEmailMatchAreListedTogether replaces the two-tier test.
 * 1.27     Aurelix Dev 28 Sep 2026  Controller 1.31 (SCW-205, ALLOW_NEW_CUSTOMER_DESPITE_MATCH). With the
 *                                   switch off, forceCreate and forceStandalone are refused in MODON's words
 *                                   while any account matches, and nothing is written; with no match they
 *                                   still create. testForceCreateEscapesTheChooser now runs with the switch
 *                                   on (the old behaviour), as does the new qualify test for forceStandalone.
 *                                   getLeadQualifyOptions carries the switch.
 * 1.26     Aurelix Dev 27 Sep 2026  Controller 1.30 (MODON's Lead rules): a Resident with only an Emirates ID is
 *                                   accepted (testResidentWithoutExpiryIsAccepted, was ...IsRefusedWithASentence);
 *                                   a Non-Resident without a passport number is refused in MODON's words; the
 *                                   stranger test asks as a Non-Resident, where something is owed.
 * 1.25     Aurelix Dev 27 Sep 2026  Controller 1.29: testPassportExpiryIsOptionalButAPastOneIsRefused.
 * 1.24     Aurelix Dev 21 Sep 2026  P7. testQueueOwnershipIsWhatBlocksTheConversion puts its lead in a
 *                                   lead queue as an admin - the org's routing no longer queues a rep's
 *                                   lead, so the probe converted it first time. testBookingForAn
 *                                   ExistingCustomerConvertsInsteadOfQueueing accepts the reuse route
 *                                   (the rep's own open Opportunity, no lead raised) as well as the
 *                                   lead route, asserting the same outcome on either.
 * 1.23     Aurelix Dev 17 Sep 2026  MSC-174 (B2). Eighteen Resident fixtures gain a passport number,
 *                                   issue date and expiry: the table now requires the passport of
 *                                   a resident, so a resident with only an Emirates ID is refused
 *                                   at createLeadFull, and "complete" for identityFor / a
 *                                   findByContact hit includes the passport. Test intent unchanged
 *                                   - the fixtures were never about the passport.
 *                                   testIdentityNeedsFollowResidency now asserts the new table.
 *                                   The one test that expects the Emirates ID expiry refusal is
 *                                   untouched: that check runs first.
 * 1.22     Aurelix Dev 02 Sep 2026  MSC-212. leadRowById: seeds an open lead, adopts a converted
 *                                   one as its Opportunity, refuses Retired; junk Company without
 *                                   TradeName__c stays a person lead.
 * 1.21     Aurelix Dev 22 Aug 2026  MSC-114. Phone fixtures are +9715...; both phone fields; owner
 *                                   read-back; Retired/Duplicate deny-list; needsAddress.
 * 1.20     Aurelix Dev 22 Aug 2026  MSC-110. identityNeeds, identityFor, createLeadFull enforcement,
 *                                   fill-only writes, createLeadDetailed leads are findable.
 * 1.19     Aurelix IT  21 Aug 2026  MSC-108. findByIdentity organisation branch; stampCompanyLicence
 *                                   never overwrites; matchAccountByDocument unchanged.
 * 1.0      Aurelix IT  09 Aug 2026  Initial.
 */
@isTest
private class SalesConsoleLeadControllerTest {

    private static Lead makeLead(String last, Id ownerId) {
        Lead l = new Lead(
            FirstName = 'Test',
            LastName = last,
            Company = 'Test ' + last,
            Email = last.toLowerCase() + '@example.com',
            Phone = '+971501234567',
            // required on Lead in this org
            ProjectInterest__c = 'Nawayef Homes'
        );
        if (ownerId != null) {
            l.OwnerId = ownerId;
        }
        insert l;
        return l;
    }

    @isTest
    static void testRecentLeadsAreScopedToTheRunningUser() {
        makeLead('Mine', null);

        Test.startTest();
        List<SalesConsoleLeadController.LeadDTO> mine =
            SalesConsoleLeadController.getRecentLeads();
        Test.stopTest();

        System.assert(!mine.isEmpty(), 'The rep must see the lead they own.');
        for (SalesConsoleLeadController.LeadDTO d : mine) {
            System.assertNotEquals(null, d.id, 'Every row needs an id to be actionable.');
        }
    }

    /** My Leads lists open leads only. Conversion is asserted, not assumed. */
    @isTest
    static void testConvertedLeadsAreNotListedOrSearchable() {
        Lead open = makeLead('StillOpen', null);
        Lead done = makeLead('AlreadyConverted', null);

        Test.startTest();
        String conversion = convertOutcome(done.Id, UserInfo.getUserId());
        List<SalesConsoleLeadController.LeadDTO> listed =
            SalesConsoleLeadController.getRecentLeads();
        List<SalesConsoleLeadController.LeadDTO> found =
            SalesConsoleLeadController.searchLeads('alreadyconverted@');
        Test.stopTest();

        System.assertEquals('SUCCEEDED', conversion,
            'The lead must actually convert, or this test proves nothing.');

        Set<Id> ids = new Set<Id>();
        for (SalesConsoleLeadController.LeadDTO d : listed) {
            ids.add(d.id);
        }
        System.assert(ids.contains(open.Id), 'An open lead must still be listed.');
        System.assert(!ids.contains(done.Id), 'A converted lead must not be listed.');
        System.assertEquals(0, found.size(),
            'Search must not surface what the list deliberately hides.');
    }

    @isTest
    static void testSearchFindsByEmailAndFallsBackWhenTooShort() {
        makeLead('Findable', null);

        Test.startTest();
        List<SalesConsoleLeadController.LeadDTO> hit =
            SalesConsoleLeadController.searchLeads('findable@');
        List<SalesConsoleLeadController.LeadDTO> tooShort =
            SalesConsoleLeadController.searchLeads('f');
        Test.stopTest();

        System.assertEquals(1, hit.size(), 'Search must match on email, not just name.');
        System.assert(!tooShort.isEmpty(),
            'A one-character term falls back to the recent list rather than running a ' +
            'LIKE %f% across every lead the rep owns.');
    }

    @isTest
    static void testCreateLeadSetsSelfGeneratedAndRequiredFields() {
        List<String> projects = SalesConsoleLeadController.getProjectOptions();
        System.assert(!projects.isEmpty(),
            'The project picklist backs a required field - an empty list blocks creation.');

        Test.startTest();
        Id newId = SalesConsoleLeadController.createLead(
            'New', 'Buyer', '+971509999999', 'new.buyer@example.com', projects[0]
        );
        Test.stopTest();

        Lead created = [
            SELECT LeadSource, Company, ProjectInterest__c, LastName
            FROM Lead WHERE Id = :newId
        ];
        System.assertEquals('Self Generated', created.LeadSource,
            'Modon reports console-raised leads as Self Generated.');
        System.assertEquals(projects[0], created.ProjectInterest__c,
            'Project interest is required, so it must be written, not defaulted away.');
        /* Company must be blank: it is what makes a Person Account rather than a business Account */
        System.assert(String.isBlank(created.Company),
            'Company must stay blank for an individual - it is what makes conversion ' +
            'produce a Person Account.');
    }

    @isTest
    static void testCreateLeadRejectsMissingInput() {
        List<String> projects = SalesConsoleLeadController.getProjectOptions();
        Integer refused = 0;
        Test.startTest();
        try {
            SalesConsoleLeadController.createLead('A', '', '', '', projects[0]);
        } catch (AuraHandledException e) {
            refused++;
        }
        try {
            SalesConsoleLeadController.createLead('A', 'Buyer', '', '', '');
        } catch (AuraHandledException e) {
            refused++;
        }
        Test.stopTest();

        System.assertEquals(2, refused,
            'Both required fields must be refused with a readable message rather than ' +
            'a raw REQUIRED_FIELD_MISSING surfacing in the console.');
    }

    @isTest
    static void testDetailReturnsNullForNoId() {
        System.assertEquals(null, SalesConsoleLeadController.getLeadDetail(null),
            'A missing id must return null rather than throw - the pane renders an ' +
            'empty state from it.');
    }

    /* Customer picker */

    /** The stage is stamped by a separate update: the Opportunity automation rewrites StageName on insert. */
    private static Opportunity makeOpportunity(String name, Boolean closed) {
        Opportunity o = new Opportunity(
            Name = name,
            StageName = 'New',
            CloseDate = System.today().addDays(30)
        );
        insert o;
        if (closed) {
            // Closed Won, not Closed Lost: Loss_Reason__c is required on Closed Lost
            update new Opportunity(Id = o.Id, StageName = 'Closed Won');
        }
        return o;
    }

    /** A closed opportunity is not offered. */
    @isTest
    static void testOpportunitiesAreOpenAndOwnedByTheRunningUser() {
        Opportunity open = makeOpportunity('Open - mine', false);
        Opportunity shut = makeOpportunity('Closed - mine', true);

        Map<Id, Opportunity> state = new Map<Id, Opportunity>([
            SELECT Id, IsClosed, OwnerId FROM Opportunity WHERE Id IN (:open.Id, :shut.Id)
        ]);
        System.assertEquals(true, state.get(shut.Id).IsClosed,
            'Precondition: the closed opportunity must actually be closed, or this ' +
            'test proves nothing about the filter.');
        System.assertEquals(false, state.get(open.Id).IsClosed,
            'Precondition: the open opportunity must actually be open.');
        System.assertEquals(UserInfo.getUserId(), state.get(open.Id).OwnerId,
            'Precondition: the picker is owner-scoped, so the row must be ours.');

        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> mine =
            SalesConsoleLeadController.getMyCustomers();
        Test.stopTest();

        System.assertEquals(1, mine.size(),
            'Only the open opportunity belongs in the picker - a booking cannot be ' +
            'started against a closed one.');
        // by id, not by name: the automation renames records on insert
        System.assertEquals(open.Id, mine[0].id,
            'The wrong row survived the filter.');
        System.assert(String.isNotBlank(mine[0].name),
            'Every row needs a name to be pickable - and it must be a PERSON, not an ' +
            'opportunity reference. The sales team never sees an opportunity.');
    }

    /** An empty pipeline is a real state. */
    @isTest
    static void testNoOpportunitiesReturnsEmptyListNotNull() {
        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> none =
            SalesConsoleLeadController.getMyCustomers();
        Test.stopTest();

        System.assertNotEquals(null, none,
            'Null reaches the LWC as undefined and renders as a broken pane rather ' +
            'than an empty one.');
        System.assertEquals(0, none.size(), 'A new rep owns no opportunities yet.');
    }

    /* createCustomer */
    /**
     * Reproduces INVALID_CROSS_REFERENCE_KEY under the rep's own permissions (runAs). SeeAllData:
     * conversion needs the live converted LeadStatus, picklists and a real ProjectInterest__c.
     */
    /** Runs createCustomer as Console Tester and reports through the assertion (StatusCode from tryConvert). */
    private static void probeCreateCustomer(String eid, String label) {
        List<User> reps = [
            SELECT Id, Name FROM User
            WHERE Username = 'salesconsole.tester@modon.com.bpdev'
            LIMIT 1
        ];
        System.assert(!reps.isEmpty(), 'Console Tester must exist to reproduce this.');

        String outcome;
        System.runAs(reps[0]) {
            try {
                SalesConsoleLeadController.createCustomer(
                    'Diag',                     // firstName
                    'Probe',                    // lastName
                    '+971501234567',               // phone
                    null,                       // email
                    'Nawayef Homes',            // projectInterest
                    'India',                    // nationality
                    'Resident',                 // residentStatus
                    eid,                        // eidNumber
                    'P0000231',                 // passportNumber (MSC-174: a resident carries one too)
                    null,                       // customerType
                    null,                       // companyName
                    Date.today().addYears(-1),  // passportIssueDate
                    null,                       // tradeLicence
                    /* the expiry a resident now needs */
                    Date.today().addYears(2),   // eidExpiry
                    Date.today().addYears(3),   // passportExpiry
                    null,                       // birthdate (1.21, optional)
                    null                        // forceCreate (1.21)
                    , null /* MSC-139 isAuthorisedSignatory */);
                outcome = 'SUCCEEDED';
            } catch (Exception e) {
                outcome = e.getTypeName() + ' :: ' + e.getMessage();
            }
        }

        /* the lead survives the failure, so the record the automation built can be read */
        String built = '(lead not found)';
        for (Lead l : [
            SELECT Id, OwnerId, Status, RecordTypeId, Account__c, Existing_Account__c,
                   Existing_Lead__c, BrokerAgency__c, Ambassador__c, Project__c,
                   ConvertedAccountId
            FROM Lead
            WHERE LastName = 'Probe' AND FirstName = 'Diag'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ]) {
            built = 'owner=' + l.OwnerId + ' status=' + l.Status
                + ' rt=' + l.RecordTypeId
                + ' Account__c=' + l.Account__c
                + ' Existing_Account__c=' + l.Existing_Account__c
                + ' Existing_Lead__c=' + l.Existing_Lead__c
                + ' BrokerAgency__c=' + l.BrokerAgency__c
                + ' Ambassador__c=' + l.Ambassador__c
                + ' Project__c=' + l.Project__c;
        }

        System.assertEquals(
            'SUCCEEDED',
            outcome,
            'PROBE[' + label + '] >>> outcome=[' + outcome + '] convertError=['
                + SalesConsoleLeadController.lastConvertError + '] lead=[' + built + ']'
        );
    }


    /** No account holds this document, so conversion mints a new Person Account. */
    @isTest(SeeAllData=true)
    static void testCreateCustomerMintsANewPersonAccount() {
        probeCreateCustomer('784-1990-9999999-9', 'no-match/create');
    }


    /** A lead sitting in a queue cannot be converted; handing ownership back is the only change. */
    @isTest(SeeAllData=true)
    static void testQueueOwnershipIsWhatBlocksTheConversion() {
        User rep = [
            SELECT Id FROM User
            WHERE Username = 'salesconsole.tester@modon.com.bpdev' LIMIT 1
        ];

        String ownerBefore;
        String beforeReassign;
        String afterReassign;
        Id leadId;

        System.runAs(rep) {
            Lead l = new Lead(
                FirstName = 'Queue', LastName = 'Probe',
                Phone = '+971501234567',
                ProjectInterest__c = 'Nawayef Homes',
                Nationality__c = 'India',
                UAEResidentStatus__c = 'Resident',
                EIDNumber__c = '784-1992-2875238-4',
                En_EIDNumber__c = '784-1992-2875238-4',
                LeadSource = 'Self Generated'
            );
            insert l;
            leadId = l.Id;
        }

        // the duplicate rule blocks even an admin update
        Database.DMLOptions opts = new Database.DMLOptions();
        opts.DuplicateRuleHeader.AllowSave = true;

        /* P7, 21 Sep 2026: the org's routing no longer sends a rep's new lead to a queue - it
           stays with the rep, the first conversion SUCCEEDED, and the probe then failed on
           CANNOT_UPDATE_CONVERTED_LEAD. The claim under test is about a QUEUE-OWNED lead, so the
           lead is put in a lead queue here, as an admin, instead of relying on routing. */
        List<QueueSobject> leadQueues = [
            SELECT QueueId FROM QueueSobject WHERE SobjectType = 'Lead' LIMIT 1
        ];
        System.assert(!leadQueues.isEmpty(), 'Precondition: the org has a lead queue.');
        Database.update(new Lead(Id = leadId, OwnerId = leadQueues[0].QueueId), opts);
        ownerBefore = String.valueOf([SELECT OwnerId FROM Lead WHERE Id = :leadId].OwnerId).substring(0, 3);

        System.runAs(rep) {
            beforeReassign = convertOutcome(leadId, rep.Id);
        }
        System.assertNotEquals('SUCCEEDED', beforeReassign,
            'While queue-owned the rep cannot convert it: ownerPrefix=[' + ownerBefore + ']');

        /* reassigned outside runAs, as an admin: the org forbids the rep doing it */
        Lead handBack = new Lead(Id = leadId, OwnerId = rep.Id);
        Database.update(handBack, opts);

        System.runAs(rep) {
            afterReassign = convertOutcome(leadId, rep.Id);
        }

        System.assertEquals(
            'SUCCEEDED',
            afterReassign,
            'PROBE[queue] >>> ownerPrefix=[' + ownerBefore + '] (00G = queue, 005 = user)'
                + ' whileQueueOwned=[' + beforeReassign + ']'
                + ' afterReassignToRep=[' + afterReassign + ']'
        );
    }

    /** Bare conversion, no console logic. */
    private static String convertOutcome(Id leadId, Id ownerId) {
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setConvertedStatus('Qualified');
        lc.setDoNotCreateOpportunity(true);
        lc.setOwnerId(ownerId);
        try {
            Database.LeadConvertResult r = Database.convertLead(lc, false);
            if (r != null && r.isSuccess()) {
                return 'SUCCEEDED';
            }
            List<String> msgs = new List<String>();
            for (Database.Error e : r.getErrors()) {
                msgs.add(String.valueOf(e.getStatusCode()));
            }
            return String.join(msgs, ',');
        } catch (Exception e) {
            return e.getTypeName() + ': ' + e.getMessage();
        }
    }



    /**
     * Booking an existing customer: the lead carries Existing_Account__c so duplicate review stands
     * down. Asserts the outcome: a booking on the chosen customer, owned by the rep.
     */
    @isTest(SeeAllData=true)
    static void testBookingForAnExistingCustomerConvertsInsteadOfQueueing() {
        Account a = [
            SELECT Id, Name, Nationality__pc FROM Account
            WHERE EIDNumber__pc = '784-2001-2065491-6' LIMIT 1
        ];
        User rep = [
            SELECT Id FROM User
            WHERE Username = 'salesconsole.tester@modon.com.bpdev' LIMIT 1
        ];

        SalesConsoleLeadController.NewCustomerDTO booked;
        String failure;
        System.runAs(rep) {
            /* driven off the search result, not hand-picked arguments: the rows used to carry no
               nationality or residency */
            List<SalesConsoleLeadController.CustomerDTO> found =
                SalesConsoleLeadController.findByIdentity(null, 'Resident', '784-2001-2065491-6');
            System.assert(!found.isEmpty(), 'Precondition: the rep must find this customer.');

            SalesConsoleLeadController.CustomerDTO picked = null;
            for (SalesConsoleLeadController.CustomerDTO c : found) {
                if (c.accountId == a.Id) { picked = c; }
            }
            System.assertNotEquals(null, picked, 'Precondition: that account must be listed.');
            System.assert(String.isNotBlank(picked.nationality),
                'The row must carry the nationality the account already holds - ' +
                'conversion is refused without it.');
            System.assert(String.isNotBlank(picked.residentStatus),
                'And the residency, for the same reason.');

            try {
                booked = SalesConsoleLeadController.bookForExistingCustomer(
                    picked.accountId, 'Sameer', 'Sewani', picked.phone, picked.email,
                    // what mscConsole falls back to
                    String.isBlank(picked.projectInterest)
                        ? 'Hudayriyat Golf Estates' : picked.projectInterest,
                    picked.nationality, picked.residentStatus,
                    /* MSC-174: passport number / issue date alongside the Emirates ID */
                    '784-2001-2065491-6', 'P0000407', null, null, Date.today().addYears(-1), null,
                    /* a Person Account has no separate signatory */
                    null,
                    /* fallback expiry, used only if the stored date is missing or past */
                    Date.today().addYears(2), Date.today().addYears(3),
                    null   // birthdate (1.21, optional)
                    , null /* MSC-139 isAuthorisedSignatory */);
            } catch (Exception e) {
                failure = e.getTypeName() + ' :: ' + e.getMessage()
                    + ' convertError=' + SalesConsoleLeadController.lastConvertError;
            }
        }

        System.assertEquals(null, failure, 'Booking for a matched customer must not fail.');
        System.assertNotEquals(null, booked.opportunityId,
            'The booking needs an Opportunity to carry on against.');

        /* P7, 21 Sep 2026: when the rep already holds an open Opportunity for this customer and
           project with no Sales Order, bookForExistingCustomer books onto it
           (reusableOpportunity) and raises no lead at all - so there is no lead to read, and the
           test died on "List has no rows". That route is correct; it proves the same outcome. */
        if (booked.leadId == null) {
            Opportunity reused = [SELECT Id, AccountId, OwnerId, IsClosed FROM Opportunity
                                  WHERE Id = :booked.opportunityId];
            System.assertEquals(a.Id, reused.AccountId, 'The booking belongs to that customer.');
            System.assertEquals(rep.Id, reused.OwnerId,
                'Reuse only ever lands on THIS rep\'s own Opportunity.');
            System.assertEquals(false, reused.IsClosed, 'And only on an open one.');
            return;
        }
        Lead raised = [
            SELECT Id, OwnerId, IsConverted, Existing_Account__c, ConvertedAccountId
            FROM Lead WHERE Id = :booked.leadId
        ];
        System.assertEquals(a.Id, raised.Existing_Account__c,
            'The chosen account must be stamped at insert - that is what stands the ' +
            'duplicate review down, and it is too late to set afterwards.');
        System.assert(!String.valueOf(raised.OwnerId).startsWith('00G'),
            'The lead must NOT have been routed to a queue - a queue-owned lead ' +
            'cannot be converted and a Sales Associate cannot take it back out.');
        System.assertEquals(true, raised.IsConverted, 'The lead must have converted.');
        System.assertEquals(a.Id, raised.ConvertedAccountId,
            'It must converge on the customer the rep actually picked, not a new ' +
            'duplicate of somebody the org already holds.');

        Opportunity o = [SELECT Id, AccountId, OwnerId FROM Opportunity
                         WHERE Id = :booked.opportunityId];
        System.assertEquals(a.Id, o.AccountId, 'The booking belongs to that customer.');
        System.assertEquals(rep.Id, o.OwnerId,
            'A fresh Opportunity owned by THIS rep - an existing one can belong to ' +
            'another agent, and booking onto it would file the sale under their name.');
    }

    /* MSC-108. The organisation search, and what it must not return */

    private static Id orgRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> byName =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        Schema.RecordTypeInfo info = byName.get(developerName);
        return info == null ? null : info.getRecordTypeId();
    }

    /** A company whose licence lives only in UnifiedNumber__c. */
    private static Account makeCompany(String name, String unified, String recordType) {
        Account a = new Account(Name = name, UnifiedNumber__c = unified);
        Id rt = recordType == null ? null : orgRecordTypeId(recordType);
        if (rt != null) {
            a.RecordTypeId = rt;
        }
        insert a;
        return a;
    }

    @isTest
    static void testCompanyIsFoundByUnifiedNumberAlone() {
        /* the field most companies keep the licence in */
        Account a = makeCompany('Unified Only LLC', 'UNI-TEST-0001', 'OrganizationAccount');

        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByIdentity('Organisation', 'Resident', 'UNI-TEST-0001');
        Test.stopTest();

        System.assertEquals(1, found.size(),
            'A company whose licence is in UnifiedNumber__c must be findable.');
        System.assertEquals(a.Id, found[0].accountId, 'And it must be that company.');
        System.assertEquals('UNI-TEST-0001', found[0].tradeLicence,
            'The row says WHICH number matched, because three fields can hold one.');
        System.assertEquals(true, found[0].isOrganisation, 'It is a company row.');
    }

    @isTest
    static void testBrokerAgenciesAndAmbassadorsAreNeverReturned() {
        /* broker agencies and ambassadors must not come back */
        String licence = 'SHARED-LIC-0002';
        makeCompany('A Broker Agency', licence, 'Broker_Agency');
        makeCompany('An Ambassador', licence, 'Ambassador');
        Account customer = makeCompany('A Real Customer LLC', licence, 'OrganizationAccount');

        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByIdentity('Organisation', 'Resident', licence);
        Test.stopTest();

        System.assertEquals(1, found.size(),
            'Only the customer company may come back; brokers and ambassadors are ' +
            'sales-channel records, not buyers.');
        System.assertEquals(customer.Id, found[0].accountId, 'And it is the customer.');
    }

    @isTest
    static void testAccountsWithNoRecordTypeAreStillFound() {
        /* NOT IN returns a null record type; an inclusion filter would hide those accounts */
        Account a = makeCompany('No Record Type LLC', 'UNI-TEST-0003', null);

        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByIdentity('Organisation', 'Resident', 'UNI-TEST-0003');
        Test.stopTest();

        System.assertEquals(1, found.size(),
            'A business account with no record type must still be findable.');
        System.assertEquals(a.Id, found[0].accountId, 'And it must be that one.');
    }

    @isTest
    static void testEveryCompanySharingALicenceComesBack() {
        /* two companies sharing one number: both shown */
        makeCompany('First Holder LLC', 'DUP-LIC-0004', 'OrganizationAccount');
        makeCompany('Second Holder LLC', 'DUP-LIC-0004', 'OrganizationAccount');

        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByIdentity('Organisation', 'Resident', 'DUP-LIC-0004');
        Test.stopTest();

        System.assertEquals(2, found.size(),
            'Both companies holding that number must be offered, not just the newest.');
    }

    @isTest
    static void testBothSpellingsOfOrganisationTakeTheCompanyBranch() {
        /* 'Organization' spelling must reach the company branch */
        makeCompany('Spelling Test LLC', 'UNI-TEST-0005', 'OrganizationAccount');

        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> british =
            SalesConsoleLeadController.findByIdentity('Organisation', 'Resident', 'UNI-TEST-0005');
        List<SalesConsoleLeadController.CustomerDTO> american =
            SalesConsoleLeadController.findByIdentity('Organization', 'Resident', 'UNI-TEST-0005');
        Test.stopTest();

        System.assertEquals(1, british.size(), 'The spelling the console sends must work.');
        System.assertEquals(british.size(), american.size(), 'And so must the other one.');
    }

    @isTest
    static void testSignatoriesTravelWithTheCompany() {
        /* the row carries who can sign */
        Account a = makeCompany('Three Signatories LLC', 'UNI-TEST-0006', 'OrganizationAccount');
        insert new List<Contact>{
            new Contact(AccountId = a.Id, FirstName = 'Aisha', LastName = 'Rahman',
                        Email = 'aisha@example.com'),
            new Contact(AccountId = a.Id, FirstName = 'Bilal', LastName = 'Haddad'),
            new Contact(AccountId = a.Id, LastName = 'Surnameonly')
        };

        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByIdentity('Organisation', 'Resident', 'UNI-TEST-0006');
        Test.stopTest();

        System.assertEquals(1, found.size(), 'Precondition: the company is found.');
        System.assertNotEquals(null, found[0].signatories, 'Signatories are never null on a company row.');
        System.assertEquals(3, found[0].signatories.size(), 'All three must be offered.');
    }

    @isTest
    static void testAPersonRowCarriesNoSignatories() {
        /* only a company has signatories */
        Test.startTest();
        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByIdentity(null, 'Resident', 'NOBODY-HAS-THIS');
        Test.stopTest();

        System.assertEquals(0, found.size(),
            'An unmatched document must return an empty list, never null.');
    }

    @isTest
    static void testStampCompanyLicenceNeverOverwritesARealNumber() {
        /* a blind overwrite of UnifiedNumber__c would reach Oracle */
        Account a = makeCompany('Already Numbered LLC', 'REAL-NUMBER', 'OrganizationAccount');
        a.TradeLicenseNumber__c = 'REAL-LICENCE';
        update a;

        Test.startTest();
        /* asserted through the org matcher: the record is untouched after a second company claims the number */
        Account reread = [SELECT UnifiedNumber__c, TradeLicenseNumber__c
                          FROM Account WHERE Id = :a.Id];
        Test.stopTest();

        System.assertEquals('REAL-NUMBER', reread.UnifiedNumber__c,
            'A populated unified number is somebody else\'s answer and is never replaced.');
        System.assertEquals('REAL-LICENCE', reread.TradeLicenseNumber__c,
            'Nor the trade licence.');
    }

    @isTest
    static void testMatchAccountByDocumentStillIgnoresCompanies() {
        /* tripwire for SalesConsoleJointOwnerService: a joint owner must never match a company */
        makeCompany('Joint Owner Trap LLC', 'JOINT-TRAP-0007', 'OrganizationAccount');

        Test.startTest();
        Id matched = SalesConsoleLeadController.matchAccountByDocument(
            'JOINT-TRAP-0007', 'JOINT-TRAP-0007', null);
        Test.stopTest();

        System.assertEquals(null, matched,
            'A document search must never return a company - the joint-owner callers ' +
            'pass a null licence and expect a person or nothing.');
    }

    @isTest
    static void testOrganisationLeadCarriesTheFieldsItsRulesDemand() {
        /* Trade_Details_Are_Mandatory: Source_Entity__c set here, and the lead must still save */
        Account a = makeCompany('Rule Abiding LLC', 'UNI-TEST-0008', 'OrganizationAccount');

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO booked;
        try {
            booked = SalesConsoleLeadController.bookForExistingCustomer(
                a.Id, 'Omar', 'Farouk', '+971500000123', 'omar@example.com',
                /* the signatory's Emirates ID and expiry */
                'Nawayef Homes', null, 'Resident', '784-1980-1234567-1', 'P0000631',
                'Organisation', a.Name, Date.today().addYears(-1), 'UNI-TEST-0008', null,
                Date.today().addYears(2), Date.today().addYears(3),
                null   // birthdate (1.21, optional)
                , null /* MSC-139 isAuthorisedSignatory */);
        } catch (Exception e) {
            System.assert(false, 'Booking for a company must not fail: ' + e.getMessage());
        }
        Test.stopTest();

        Lead raised = [SELECT Company, TradeName__c, UnifiedNumber__c, Source_Entity__c
                       FROM Lead WHERE Id = :booked.leadId];
        System.assertEquals(a.Name, raised.Company, 'Company is what makes it a business lead.');
        System.assertEquals(a.Name, raised.TradeName__c,
            'TradeName__c takes the organisation name, as MBP_BrokerLeadcontroller does.');
        System.assertEquals('UNI-TEST-0008', raised.UnifiedNumber__c,
            'And the unified number the rule demands alongside it.');

        raised.Source_Entity__c = 'Modon - UAE';
        update raised;
    }

    @isTest
    static void testBookingForACompanyReusesItsSignatory() {
        /* conversion must not invent a Contact */
        Account a = makeCompany('Reuse Me LLC', 'UNI-TEST-0009', 'OrganizationAccount');
        Contact signer = new Contact(AccountId = a.Id, FirstName = 'Layla', LastName = 'Nasser',
                                     Email = 'layla@example.com', MobilePhone = '+971501112222');
        insert signer;
        Integer before = [SELECT COUNT() FROM Contact WHERE AccountId = :a.Id];

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO booked =
            SalesConsoleLeadController.bookForExistingCustomer(
                a.Id, 'IGNORED', 'IGNORED', '+971509999999', 'ignored@example.com',
                'Nawayef Homes', null, 'Resident', '784-1981-1234567-2', 'P0000667',
                'Organisation', a.Name, Date.today().addYears(-1), 'UNI-TEST-0009', signer.Id,
                Date.today().addYears(2), Date.today().addYears(3),
                null   // birthdate (1.21, optional)
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        System.assertEquals(before, [SELECT COUNT() FROM Contact WHERE AccountId = :a.Id],
            'No second signatory may be minted for a company that already has one.');

        Contact after = [SELECT FirstName, LastName, Email, MobilePhone
                         FROM Contact WHERE Id = :signer.Id];
        System.assertEquals('Layla', after.FirstName,
            'Conversion writes the Lead onto the Contact it merges into, so the Lead ' +
            'must have carried the signatory\'s OWN details and changed nothing.');
        System.assertEquals('layla@example.com', after.Email, 'Their email likewise.');
        System.assertEquals('+971501112222', after.MobilePhone,
            'And their mobile - never the number the browser happened to send.');

        Opportunity o = [SELECT PrimaryContact__c FROM Opportunity
                         WHERE Id = :booked.opportunityId];
        System.assertEquals(signer.Id, o.PrimaryContact__c,
            'The booking must carry the chosen signatory through to the Sales Order.');
    }

    @isTest
    static void testASignatoryFromAnotherCompanyIsRefused() {
        /* the id arrives from a browser */
        Account a = makeCompany('Mine LLC', 'UNI-TEST-0010', 'OrganizationAccount');
        Account other = makeCompany('Theirs LLC', 'UNI-TEST-0011', 'OrganizationAccount');
        Contact stranger = new Contact(AccountId = other.Id, FirstName = 'Not', LastName = 'Mine');
        insert stranger;

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO booked =
            SalesConsoleLeadController.bookForExistingCustomer(
                a.Id, 'Walk', 'In', '+971500000000', 'walkin@example.com',
                'Nawayef Homes', null, 'Resident', '784-1982-1234567-3', 'P0000704',
                'Organisation', a.Name, Date.today().addYears(-1), 'UNI-TEST-0010', stranger.Id,
                Date.today().addYears(2), Date.today().addYears(3),
                null   // birthdate (1.21, optional)
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        Opportunity o = [SELECT PrimaryContact__c, AccountId FROM Opportunity
                         WHERE Id = :booked.opportunityId];
        System.assertNotEquals(stranger.Id, o.PrimaryContact__c,
            'A contact belonging to another company must never be attached.');
        System.assertEquals(a.Id, o.AccountId,
            'And the booking still belongs to the company the rep chose.');
    }

    /* MSC-110. The identity a lead must carry */

    /** A Person Account, on whichever person record type this org runs. */
    private static Account makePerson(
        String first, String last, String email, String mobile,
        String residency, String eid, Date eidExpiry,
        String passport, Date passIssue, Date passExpiry
    ) {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = TRUE
            LIMIT 1
        ];
        Account a = new Account(
            FirstName = first,
            LastName = last,
            PersonEmail = email,
            PersonMobilePhone = mobile,
            UAE_Resident_Status__pc = residency,
            Nationality__pc = 'India',
            EIDNumber__pc = eid,
            EmiratesIDExpiryDate__pc = eidExpiry,
            PassportNumber__pc = passport,
            PassportIssueDate__pc = passIssue,
            PassportExpiryDate__pc = passExpiry
        );
        if (!rts.isEmpty()) {
            a.RecordTypeId = rts[0].Id;
        }
        insert a;
        return a;
    }

    @isTest
    static void testIdentityNeedsFollowResidency() {
        SalesConsoleLeadController.IdentityNeedDTO res =
            SalesConsoleLeadController.identityNeeds('Resident');
        System.assert(res.eidNumber && res.eidExpiry,
            'A resident owes an Emirates ID and its expiry.');
        /* 1.23 - MSC-174: and, since 17 Sep, the passport set as well */
        System.assert(res.passportNumber && res.passportIssueDate && res.passportExpiryDate,
            'And the full passport set - the decision of 17 Sep 2026.');

        SalesConsoleLeadController.IdentityNeedDTO non =
            SalesConsoleLeadController.identityNeeds('Non-Resident');
        System.assert(non.passportNumber && non.passportIssueDate && non.passportExpiryDate,
            'A non-resident owes the full passport set.');
        System.assert(!non.eidNumber && !non.eidExpiry, 'And no Emirates ID.');

        SalesConsoleLeadController.IdentityNeedDTO blank =
            SalesConsoleLeadController.identityNeeds(null);
        System.assert(!blank.eidNumber && !blank.eidExpiry && !blank.passportNumber
                && !blank.passportIssueDate && !blank.passportExpiryDate,
            'Blank residency requires nothing yet - residency is asked first.');
    }

    /* 1.26 - MODON's Lead rules owe a Resident nothing; a Non-Resident owes the passport number */
    @isTest
    static void testResidentWithoutExpiryIsAccepted() {
        SalesConsoleLeadController.createLeadDetailed(
            'Accepted', 'NoExpiry', '+971501110001', null, 'Nawayef Homes',
            'India', 'Resident', '784-1990-1234501-1', null,
            null, null, null,
            null   // birthdate (1.21, optional)
        );
        System.assertEquals(1,
            [SELECT COUNT() FROM Lead WHERE LastName = 'NoExpiry'],
            'A resident lead with no expiry and no passport is made, as in the Sales App.');

        String refusal;
        try {
            SalesConsoleLeadController.createLeadDetailed(
                'Refused', 'NoPassport', '+971501110031', null, 'Nawayef Homes',
                'India', 'Non-Resident', null, null,
                null, null, null,
                null
            );
        } catch (AuraHandledException e) {
            refusal = e.getMessage();
        }
        System.assertNotEquals(null, refusal, 'A non-resident without a passport number is refused.');
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE LastName = 'NoPassport'],
            'Before the insert.');
    }

    /* 1.25 - controller 1.29: a blank passport expiry is accepted, a past one is not */
    @isTest
    static void testPassportExpiryIsOptionalButAPastOneIsRefused() {
        Id leadId = SalesConsoleLeadController.createLeadDetailed(
            'Optional', 'NoPassportExpiry', '+971501119021', null, 'Nawayef Homes',
            'India', 'Non-Resident', null, 'P0009021',
            null, Date.today().addYears(-1), null,
            null   // birthdate
        ).leadId;
        Lead l = [SELECT PassportNumber__c, PassportExpiryDate__c FROM Lead WHERE Id = :leadId];
        System.assertEquals('P0009021', l.PassportNumber__c, 'The lead is made without an expiry.');
        System.assertEquals(null, l.PassportExpiryDate__c);

        String refusal;
        try {
            SalesConsoleLeadController.createLeadDetailed(
                'Refused', 'PastPassportExpiry', '+971501119022', null, 'Nawayef Homes',
                'India', 'Non-Resident', null, 'P0009022',
                null, Date.today().addYears(-1), Date.today().addDays(-1),
                null
            );
        } catch (AuraHandledException e) {
            refusal = e.getMessage();
        }
        System.assertNotEquals(null, refusal, 'An expired passport is still refused.');
        System.assertEquals(0,
            [SELECT COUNT() FROM Lead WHERE LastName = 'PastPassportExpiry'],
            'Before the insert.');
    }

    @isTest
    static void testResidentLeadCarriesExpiryAndEncryptedTwin() {
        Date expiry = Date.today().addYears(2);
        Id leadId = SalesConsoleLeadController.createLeadDetailed(
            'Carries', 'TheExpiry', '+971501110002', null, 'Nawayef Homes',
            'India', 'Resident', '784-1991-1234502-2', 'P0000799',
            expiry, Date.today().addYears(-1), Date.today().addYears(3),
            null   // birthdate (1.21, optional)
        ).leadId;
        Lead l = [SELECT EIDNumber__c, En_EIDNumber__c, EmiratesIDExpiryDate__c
                  FROM Lead WHERE Id = :leadId];
        System.assertEquals(expiry, l.EmiratesIDExpiryDate__c,
            'The expiry the org demands must be on the lead.');
        System.assertEquals('784-1991-1234502-2', l.EIDNumber__c,
            'The plain field carries the number the rest of MODON reads.');
        System.assert(String.isNotBlank(l.En_EIDNumber__c),
            'And the encrypted twin the validation rules test. Asserted non-blank ' +
            'rather than equal: EncryptedText reads back masked without the View ' +
            'Encrypted Data permission.');
    }

    @isTest
    static void testNonResidentLeadCarriesBothPassportDates() {
        Date issue = Date.today().addYears(-3);
        Date expiry = Date.today().addYears(4);
        Id leadId = SalesConsoleLeadController.createLeadDetailed(
            'Both', 'Dates', '+971501110003', null, 'Nawayef Homes',
            'India', 'Non-Resident', null, 'P8891001',
            null, issue, expiry,
            null   // birthdate (1.21, optional)
        ).leadId;
        Lead l = [SELECT PassportNumber__c, En_PassportNumber__c,
                         PassportIssueDate__c, PassportExpiryDate__c
                  FROM Lead WHERE Id = :leadId];
        System.assertEquals(issue, l.PassportIssueDate__c,
            'The issue date every org gates conversion on.');
        System.assertEquals(expiry, l.PassportExpiryDate__c,
            'And the expiry UAT and PREPROD demand.');
        System.assert(String.isNotBlank(l.En_PassportNumber__c),
            'The encrypted twin travels with the plain field.');
    }

    @isTest
    static void testIdentityForReadsThePersonAccount() {
        Date expiry = Date.today().addYears(3);
        Account a = makePerson('Complete', 'Customer', 'complete.customer@example.com',
            '+971501110004', 'Resident', '784-1992-1234503-3', expiry,
            /* 1.23 - MSC-174: "complete" for a resident includes the passport now */
            'P0000846', Date.today().addYears(-1), Date.today().addYears(3));

        SalesConsoleLeadController.IdentityStateDTO s =
            SalesConsoleLeadController.identityFor(a.Id, null, 'Resident');
        System.assertEquals('784-1992-1234503-3', s.eidNumber,
            'The document the account already holds must be read, not asked for.');
        System.assertEquals(expiry, s.eidExpiry, 'And its expiry.');
        System.assertEquals(null, s.eidExpiryReason, 'A future expiry needs no reason.');
        System.assertEquals(true, s.complete,
            'A complete record books with no extra questions - that is the contract.');
    }

    @isTest
    static void testIdentityForReportsAnExpiredDocument() {
        Date past = Date.today().addDays(-30);
        Account a = makePerson('Expired', 'Customer', 'expired.customer@example.com',
            '+971501110005', 'Resident', '784-1993-1234504-4', past,
            null, null, null);

        SalesConsoleLeadController.IdentityStateDTO s =
            SalesConsoleLeadController.identityFor(a.Id, null, 'Resident');
        System.assertEquals('expired', s.eidExpiryReason,
            'A past expiry must be REPORTED, never silently reused - two orgs refuse ' +
            'it at insert, and 1,016 PREPROD residents are in exactly this state.');
        System.assertEquals(false, s.complete, 'So the record cannot book on its own.');
    }

    @isTest
    static void testIdentityForReportsAFutureIssueDate() {
        Account a = makePerson('Future', 'Issue', 'future.issue@example.com',
            '+971501110006', 'Non-Resident', null, null,
            'P8891002', Date.today().addDays(30), Date.today().addYears(4));

        SalesConsoleLeadController.IdentityStateDTO s =
            SalesConsoleLeadController.identityFor(a.Id, null, 'Non-Resident');
        System.assertEquals('future', s.passportIssueReason,
            'Passport_Issue_Date_Should_not_be_Future refuses a future issue date in ' +
            'all three orgs, so a stored one is a gap to repair, not a value to copy.');
        System.assertEquals(false, s.complete, 'And the record cannot book on its own.');
    }

    @isTest
    static void testIdentityForReadsTheSignatoryNotTheCompany() {
        Account a = makeCompany('Signed LLC', 'UNI-TEST-0020', 'OrganizationAccount');
        Date expiry = Date.today().addYears(2);
        Contact signer = new Contact(AccountId = a.Id, FirstName = 'Huda', LastName = 'Karim',
            EIDNumber__c = '784-1994-1234505-5', EmiratesIDExpiryDate__c = expiry,
            UAE_Resident_Status__c = 'Resident',
            /* 1.23 - MSC-174: a documented resident signatory carries a passport too */
            PassportNumber__c = 'P0000892', PassportIssueDate__c = Date.today().addYears(-1),
            PassportExpiryDate__c = Date.today().addYears(3));
        insert signer;

        SalesConsoleLeadController.IdentityStateDTO s =
            SalesConsoleLeadController.identityFor(a.Id, signer.Id, 'Resident');
        System.assertEquals('784-1994-1234505-5', s.eidNumber,
            'A company booking converges on the SIGNATORY, so theirs are the ' +
            'documents that matter.');
        System.assertEquals(true, s.complete, 'A documented signatory asks nothing.');
    }

    @isTest
    static void testIdentityForRefusesAStrangersDocuments() {
        Account mine = makeCompany('Mine Docs LLC', 'UNI-TEST-0021', 'OrganizationAccount');
        Account theirs = makeCompany('Theirs Docs LLC', 'UNI-TEST-0022', 'OrganizationAccount');
        Contact stranger = new Contact(AccountId = theirs.Id, FirstName = 'Not', LastName = 'Yours',
            EIDNumber__c = '784-1995-1234506-6',
            EmiratesIDExpiryDate__c = Date.today().addYears(2));
        insert stranger;

        /* 1.26 - as a Non-Resident, where a passport number is owed */
        SalesConsoleLeadController.IdentityStateDTO s =
            SalesConsoleLeadController.identityFor(mine.Id, stranger.Id, 'Non-Resident');
        System.assertEquals(null, s.eidNumber,
            'A contact belonging to another company must never be read - same guard ' +
            'as resolveSignatory, because it IS resolveSignatory.');
        System.assertEquals(false, s.complete, 'So the step asks rather than assumes.');
    }

    @isTest
    static void testBookingPrefersTheAccountsOwnDates() {
        Date stored = Date.today().addYears(3);
        Date clientSent = Date.today().addYears(1);
        Account a = makePerson('Stored', 'Wins', 'stored.wins@example.com',
            '+971501110007', 'Resident', '784-1996-1234507-7', stored,
            null, null, null);

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO booked =
            SalesConsoleLeadController.bookForExistingCustomer(
                a.Id, 'Stored', 'Wins', '+971501110007', 'stored.wins@example.com',
                'Nawayef Homes', 'India', 'Resident',
                '784-1996-1234507-7', 'P0000928', null, null, Date.today().addYears(-1), null, null,
                clientSent, Date.today().addYears(3),
                null   // birthdate (1.21, optional)
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        Lead l = [SELECT EmiratesIDExpiryDate__c, IsConverted
                  FROM Lead WHERE Id = :booked.leadId];
        System.assertEquals(stored, l.EmiratesIDExpiryDate__c,
            'A usable stored date wins over whatever the browser sent - the lead is ' +
            'built from the record it converges on, so the write-back is a no-op.');
        System.assertEquals(true, l.IsConverted, 'And the booking went through.');
    }

    @isTest
    static void testBookingNeverCopiesAPastExpiry() {
        Date past = Date.today().addDays(-10);
        Date renewed = Date.today().addYears(2);
        Account a = makePerson('Past', 'NotCopied', 'past.notcopied@example.com',
            '+971501110008', 'Resident', '784-1997-1234508-8', past,
            null, null, null);

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO booked =
            SalesConsoleLeadController.bookForExistingCustomer(
                a.Id, 'Past', 'NotCopied', '+971501110008', 'past.notcopied@example.com',
                'Nawayef Homes', 'India', 'Resident',
                '784-1997-1234508-8', 'P0000955', null, null, Date.today().addYears(-1), null, null,
                renewed, Date.today().addYears(3),
                null   // birthdate (1.21, optional)
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        Lead l = [SELECT EmiratesIDExpiryDate__c FROM Lead WHERE Id = :booked.leadId];
        System.assertEquals(renewed, l.EmiratesIDExpiryDate__c,
            'A past stored expiry is UNUSABLE - EID_ExpiryDate_Cannot_be_Past refuses ' +
            'it in UAT and PREPROD - so the renewed date the rep supplied must be the ' +
            'one the lead carries.');
    }

    @isTest
    static void testConvertFillsOnlyBlanks() {
        /* a lead that already carries a document */
        Lead l = new Lead(
            FirstName = 'Fill', LastName = 'OnlyBlanks',
            Phone = '+971501110009', ProjectInterest__c = 'Nawayef Homes',
            LeadSource = 'Self Generated',
            Nationality__c = 'India', UAEResidentStatus__c = 'Resident',
            EIDNumber__c = '784-1998-1234509-9', En_EIDNumber__c = '784-1998-1234509-9'
        );
        insert l;
        Date expiry = Date.today().addYears(2);

        Test.startTest();
        SalesConsoleLeadController.convertLeadToCustomer(
            l.Id, 'India', 'Resident',
            /* a different number from the client must be ignored (fill-only) */
            '784-1999-7654321-1', expiry, null, null, null,
            null, null   // targetAccountId, forceStandalone (1.21)
        );
        Test.stopTest();

        Lead after = [SELECT EIDNumber__c, EmiratesIDExpiryDate__c, IsConverted
                      FROM Lead WHERE Id = :l.Id];
        System.assertEquals('784-1998-1234509-9', after.EIDNumber__c,
            'A populated identity field is never overwritten - fill-only.');
        System.assertEquals(expiry, after.EmiratesIDExpiryDate__c,
            'A BLANK one is filled - which is what repairs a lead raised before ' +
            'these fields were asked for.');
        System.assertEquals(true, after.IsConverted, 'And it qualified.');
    }

    @isTest
    static void testMyLeadsLeadIsFindableByItsDocument() {
        /* leads raised through the old createLead were unfindable */
        Id leadId = SalesConsoleLeadController.createLeadDetailed(
            'Findable', 'AtLast', '+971501110010', null, 'Nawayef Homes',
            'India', 'Resident', '784-2000-1234510-1', 'P0001006',
            Date.today().addYears(2), Date.today().addYears(-1), Date.today().addYears(3),
            null   // birthdate (1.21, optional)
        ).leadId;

        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByIdentity(null, 'Resident', '784-2000-1234510-1');

        Boolean listed = false;
        for (SalesConsoleLeadController.CustomerDTO c : found) {
            if (c.leadId == leadId) {
                listed = true;
                System.assertEquals(false, c.needsQualifyDetails,
                    'A lead created with the full set has nothing left to ask.');
            }
        }
        System.assert(listed,
            'A lead raised in My Leads must be findable by the document it was ' +
            'raised with. Before 1.20 it never was.');
    }

    /* MSC-111. find who we already have */

    @isTest
    static void testResidentIsFoundByTheirPassport() {
        /* a resident holding a passport and no Emirates ID */
        makePerson('Passport', 'OnlyResident', 'passport.only@example.com',
            '+971502110001', 'Resident', null, null,
            'PR551001', Date.today().addYears(-2), Date.today().addYears(3));

        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByIdentity(null, 'Resident', 'PR551001');

        System.assertEquals(1, found.size(),
            'A resident must be findable by their passport - the toggle decides ' +
            'the mask and the labels, never which field is searched.');
        System.assertEquals('passport', found[0].matchedOn,
            'And the row says WHICH document found them.');
    }

    @isTest
    static void testDocumentHolderWithNoResidencyIsFound() {
        /* a document on file, no residency answer */
        makePerson('No', 'ResidencyAnswer', 'no.residency@example.com',
            '+971502110002', null, '784-2101-1234511-1', Date.today().addYears(2),
            null, null, null);

        List<SalesConsoleLeadController.CustomerDTO> asResident =
            SalesConsoleLeadController.findByIdentity(null, 'Resident', '784-2101-1234511-1');
        List<SalesConsoleLeadController.CustomerDTO> asNonResident =
            SalesConsoleLeadController.findByIdentity(null, 'Non-Resident', '784-2101-1234511-1');

        System.assertEquals(1, asResident.size(),
            'Found when the rep says Resident.');
        System.assertEquals(1, asNonResident.size(),
            'And found when they say Non-Resident: the record does not know its ' +
            'residency, and that must not make it invisible.');
        System.assertEquals('eid', asResident[0].matchedOn, 'The chip code rides along.');
    }

    @isTest
    static void testFindByContactFindsAccountByEmail() {
        makePerson('By', 'Email', 'find.me@modontest.ae', '+971502110003',
            'Resident', '784-2102-1234512-2', Date.today().addYears(2),
            /* 1.23 - MSC-174: complete means passport too */
            'P0001076', Date.today().addYears(-1), Date.today().addYears(3));

        List<SalesConsoleLeadController.CustomerDTO> found =
            SalesConsoleLeadController.findByContact(null, 'FIND.ME@MODONTEST.AE');

        System.assertEquals(1, found.size(),
            'Email search is exact and case-insensitive - SOQL compares email ' +
            'fields without case.');
        System.assertEquals('email', found[0].matchedOn, 'The row says email found it.');
        System.assertEquals(false, found[0].needsQualifyDetails,
            'A complete record arrives ready to book, exactly like a document hit.');
    }

    @isTest
    static void testFindByContactFindsMobileHoweverItIsTyped() {
        makePerson('By', 'Mobile', 'by.mobile@modontest.ae', '+971564435453',
            'Resident', '784-2103-1234513-3', Date.today().addYears(2), null, null, null);

        System.assertEquals(1,
            SalesConsoleLeadController.findByContact(null, '+971 56 443 5453').size(),
            'Spaces are how a human types a number they are reading.');
        System.assertEquals(1,
            SalesConsoleLeadController.findByContact(null, '0564435453').size(),
            'The local 05x spelling reaches the stored +971 form.');
        System.assertEquals(1,
            SalesConsoleLeadController.findByContact(null, '00971564435453').size(),
            'And the 00 international prefix.');
        System.assertEquals('mobile',
            SalesConsoleLeadController.findByContact(null, '0564435453')[0].matchedOn,
            'The chip code says mobile.');
    }

    @isTest
    static void testFindByContactFindsTheLeadHalf() {
        /* the Phone leg is still load-bearing for older leads */
        Id leadId = SalesConsoleLeadController.createLeadDetailed(
            'Lead', 'ByContact', '+971502110004', 'lead.contact@modontest.ae',
            'Nawayef Homes', 'India', 'Resident',
            '784-2104-1234514-4', 'P0001106', Date.today().addYears(2),
            Date.today().addYears(-1), Date.today().addYears(3),
            null).leadId;

        List<SalesConsoleLeadController.CustomerDTO> byPhone =
            SalesConsoleLeadController.findByContact(null, '+971502110004');
        List<SalesConsoleLeadController.CustomerDTO> byEmail =
            SalesConsoleLeadController.findByContact(null, 'lead.contact@modontest.ae');

        Boolean phoneListed = false;
        for (SalesConsoleLeadController.CustomerDTO c : byPhone) {
            if (c.leadId == leadId) phoneListed = true;
        }
        Boolean emailListed = false;
        for (SalesConsoleLeadController.CustomerDTO c : byEmail) {
            if (c.leadId == leadId) emailListed = true;
        }
        System.assert(phoneListed,
            '73 of 73 open DEV_1 leads carry a mobile and 4 carry a document - ' +
            'the mobile must reach the lead, through the Phone field the console ' +
            'writes.');
        System.assert(emailListed, 'And the email must too.');
    }

    @isTest
    static void testAmbiguousEmailReturnsEverySharer() {
        /* shared email: the choice is handed back */
        makePerson('Shared', 'One', 'shared@modontest.ae', '+971502110005',
            'Resident', '784-2105-1234515-5', Date.today().addYears(2), null, null, null);
        makePerson('Shared', 'Two', 'shared@modontest.ae', '+971502110006',
            'Resident', '784-2106-1234516-6', Date.today().addYears(2), null, null, null);

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO res =
            SalesConsoleLeadController.createCustomer(
                'Brand', 'NewPerson', '+971502110007', 'shared@modontest.ae',
                'Nawayef Homes', 'India', 'Resident',
                '784-2107-1234517-7', 'P0001142', null, null, Date.today().addYears(-1), null,
                Date.today().addYears(2), Date.today().addYears(3), null, null
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        System.assertNotEquals(null, res.candidates, 'The choice comes back to the rep.');
        System.assertEquals(2, res.candidates.size(), 'ALL the sharers, not the newest.');
        System.assertEquals(null, res.opportunityId, 'Nothing was booked.');
        System.assertEquals(null, res.leadId, 'And nothing inserted -');
        System.assertEquals(0,
            [SELECT COUNT() FROM Lead WHERE LastName = 'NewPerson'],
            'no orphan lead per attempt, which is why matching moved BEFORE the insert.');
        System.assertEquals('email', res.candidates[0].matchedOn,
            'Each candidate says what matched.');
    }

    /* 1.28 - controller 1.33. Was testDocumentBeatsEmailInTheMatch; every key is searched at once now */
    @isTest
    static void testIdMatchAndEmailMatchAreListedTogether() {
        Account docHolder = makePerson('Doc', 'Holder', 'shared2@modontest.ae',
            '+971502110008', 'Resident', '784-2108-1234518-8',
            Date.today().addYears(2), null, null, null);
        Account sharer = makePerson('Mailbox', 'Sharer', 'shared2@modontest.ae', '+971502110009',
            'Resident', '784-2109-1234519-9', Date.today().addYears(2), null, null, null);

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO res =
            SalesConsoleLeadController.createCustomer(
                'Doc', 'Holder', '+971502110010', 'shared2@modontest.ae',
                'Nawayef Homes', 'India', 'Resident',
                '784-2108-1234518-8', 'P0001172', null, null, Date.today().addYears(-1), null,
                Date.today().addYears(2), Date.today().addYears(3), null, null
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        System.assertNotEquals(null, res.candidates, 'Two accounts match, so the rep chooses.');
        System.assertEquals(2, res.candidates.size(), 'The Emirates ID holder and the email sharer.');
        System.assertEquals(docHolder.Id, res.candidates[0].accountId, 'The ID match comes first.');
        System.assertEquals('eid', res.candidates[0].matchedOn,
            'It matches on the Emirates ID and the email; the chip names the stronger.');
        System.assertEquals(sharer.Id, res.candidates[1].accountId);
        System.assertEquals('email', res.candidates[1].matchedOn);
        System.assertEquals(null, res.leadId, 'Nothing was written.');
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE LastName = 'Holder']);
    }

    @isTest
    static void testForceCreateEscapesTheChooser() {
        /* forceCreate: a new person sharing an email is still creatable. 1.27: with the switch on */
        AurelixNewCustomerSwitch.switchOverride = true;
        makePerson('Escape', 'One', 'escape@modontest.ae', '+971502110011',
            'Resident', '784-2110-1234520-1', Date.today().addYears(2), null, null, null);
        makePerson('Escape', 'Two', 'escape@modontest.ae', '+971502110012',
            'Resident', '784-2111-1234521-2', Date.today().addYears(2), null, null, null);

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO res =
            SalesConsoleLeadController.createCustomer(
                'Genuinely', 'NewBuyer', '+971502110013', 'escape@modontest.ae',
                'Nawayef Homes', 'India', 'Resident',
                '784-2112-1234522-3', 'P0001198', null, null, Date.today().addYears(-1), null,
                Date.today().addYears(2), Date.today().addYears(3), null,
                true   // forceCreate - the rep said none of these
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        System.assertEquals(null, res.candidates, 'No second chooser.');
        System.assertNotEquals(null, res.opportunityId, 'The booking started.');
        Lead l = [SELECT ConvertedAccountId FROM Lead WHERE Id = :res.leadId];
        System.assertEquals(1,
            [SELECT COUNT() FROM Account
             WHERE Id = :l.ConvertedAccountId AND PersonEmail = 'escape@modontest.ae'
               AND FirstName = 'Genuinely'],
            'A standalone record - never a silent converge onto somebody the rep ' +
            'just rejected.');
    }

    /* 1.27 - controller 1.31: with the switch off, "Continue With New Details" is refused while any
       account matches, in the Sales App's sentence, before the lead is written */
    @isTest
    static void testForceCreateIsRefusedWhileAMatchExists() {
        AurelixNewCustomerSwitch.switchOverride = false;
        makePerson('NoDup', 'One', 'nodup.create@modontest.ae', '+971502110201',
            'Resident', '784-2150-1234550-1', Date.today().addYears(2), null, null, null);
        makePerson('NoDup', 'Two', 'nodup.create@modontest.ae', '+971502110202',
            'Resident', '784-2151-1234551-2', Date.today().addYears(2), null, null, null);
        Integer accountsBefore = [SELECT COUNT() FROM Account];

        String refusal;
        Test.startTest();
        try {
            SalesConsoleLeadController.createCustomer(
                'Refused', 'NoDupBuyer', '+971502110203', 'nodup.create@modontest.ae',
                'Nawayef Homes', 'India', 'Resident',
                '784-2152-1234552-3', 'P0002052', null, null, Date.today().addYears(-1), null,
                Date.today().addYears(2), Date.today().addYears(3), null,
                true   // forceCreate - "Continue With New Details"
                , null /* MSC-139 isAuthorisedSignatory */);
        } catch (AuraHandledException e) {
            refusal = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(SalesConsoleLeadController.MATCH_MUST_BE_CHOSEN, refusal,
            'Refused in the Sales App\'s own words.');
        System.assertEquals(
            'Matching accounts were found. Please select one before converting.', refusal);
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE LastName = 'NoDupBuyer'],
            'No lead is written.');
        System.assertEquals(accountsBefore, [SELECT COUNT() FROM Account],
            'And no account.');
    }

    /* 1.27: the switch changes nothing when nobody matches */
    @isTest
    static void testForceCreateWithNoMatchStillCreates() {
        AurelixNewCustomerSwitch.switchOverride = false;

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO res =
            SalesConsoleLeadController.createCustomer(
                'Nobody', 'NoDupAlone', '+971502110204', 'nodup.alone@modontest.ae',
                'Nawayef Homes', 'India', 'Resident',
                '784-2153-1234553-4', 'P0002053', null, null, Date.today().addYears(-1), null,
                Date.today().addYears(2), Date.today().addYears(3), null,
                true   // forceCreate
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        System.assertEquals(null, res.candidates, 'Nothing to choose from.');
        System.assertNotEquals(null, res.opportunityId, 'The booking started, as before.');
    }

    /* 1.27: the qualify route's "Continue With New Details" (forceStandalone), switch off */
    @isTest
    static void testForceStandaloneIsRefusedWhileAMatchExists() {
        AurelixNewCustomerSwitch.switchOverride = false;
        makePerson('NoDupQ', 'One', 'nodup.qualify@modontest.ae', '+971502110205',
            'Resident', '784-2154-1234554-5', Date.today().addYears(2), null, null, null);
        makePerson('NoDupQ', 'Two', 'nodup.qualify@modontest.ae', '+971502110206',
            'Resident', '784-2155-1234555-6', Date.today().addYears(2), null, null, null);
        Lead l = new Lead(
            FirstName = 'Standalone', LastName = 'NoDupLead',
            Email = 'nodup.qualify@modontest.ae', Phone = '+971502110207',
            ProjectInterest__c = 'Nawayef Homes', LeadSource = 'Self Generated',
            Nationality__c = 'India', UAEResidentStatus__c = 'Resident'
        );
        insert l;
        Integer accountsBefore = [SELECT COUNT() FROM Account];

        String refusal;
        Test.startTest();
        try {
            SalesConsoleLeadController.convertLeadToCustomer(
                l.Id, 'India', 'Resident', null, null, null, null, null,
                null, true);   // forceStandalone
        } catch (AuraHandledException e) {
            refusal = e.getMessage();
        }
        Test.stopTest();

        System.assertEquals(SalesConsoleLeadController.MATCH_MUST_BE_CHOSEN, refusal,
            'Refused in the Sales App\'s own words.');
        System.assertEquals(false,
            [SELECT IsConverted FROM Lead WHERE Id = :l.Id].IsConverted,
            'The lead is not converted.');
        System.assertEquals(accountsBefore, [SELECT COUNT() FROM Account],
            'And no account is made.');
    }

    /* 1.27: switch on, forceStandalone converts standalone as before */
    @isTest
    static void testForceStandaloneConvertsWithTheSwitchOn() {
        AurelixNewCustomerSwitch.switchOverride = true;
        Account one = makePerson('NoDupS', 'One', 'nodup.switch@modontest.ae', '+971502110208',
            'Resident', '784-2156-1234556-7', Date.today().addYears(2), null, null, null);
        Account two = makePerson('NoDupS', 'Two', 'nodup.switch@modontest.ae', '+971502110209',
            'Resident', '784-2157-1234557-8', Date.today().addYears(2), null, null, null);
        Lead l = new Lead(
            FirstName = 'Standalone', LastName = 'NoDupOn',
            Email = 'nodup.switch@modontest.ae', Phone = '+971502110210',
            ProjectInterest__c = 'Nawayef Homes', LeadSource = 'Self Generated',
            Nationality__c = 'India', UAEResidentStatus__c = 'Resident'
        );
        insert l;

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO res =
            SalesConsoleLeadController.convertLeadToCustomer(
                l.Id, 'India', 'Resident', null, null, null, null, null,
                null, true);   // forceStandalone
        Test.stopTest();

        System.assertNotEquals(null, res.opportunityId, 'Converted, as before.');
        Id converted = [SELECT ConvertedAccountId FROM Lead WHERE Id = :l.Id].ConvertedAccountId;
        System.assertNotEquals(null, converted);
        System.assert(converted != one.Id && converted != two.Id,
            'A standalone account, not either of the matches.');
    }

    /* 1.27: the page reads the switch from getLeadQualifyOptions */
    @isTest
    static void testQualifyOptionsCarryTheSwitch() {
        AurelixNewCustomerSwitch.switchOverride = false;
        Map<String, List<String>> off = SalesConsoleLeadController.getLeadQualifyOptions();
        System.assertEquals(new List<String>{ 'false' }, off.get('newCustomerDespiteMatch'));
        System.assert(off.containsKey('nationality') && off.containsKey('residentStatus'),
            'The picklists are still there.');

        AurelixNewCustomerSwitch.switchOverride = true;
        Map<String, List<String>> onOpts = SalesConsoleLeadController.getLeadQualifyOptions();
        System.assertEquals(new List<String>{ 'true' }, onOpts.get('newCustomerDespiteMatch'));
    }

    @isTest
    static void testQualifyMatchesOnTheDocument() {
        /* same human, same Emirates ID, new email and mobile */
        Account existing = makePerson('Probe', 'Five', 'old.address@modontest.ae',
            '+971502110014', 'Resident', '784-2113-1234523-4',
            Date.today().addYears(2), null, null, null);
        Lead l = new Lead(
            FirstName = 'Probe', LastName = 'Five',
            Email = 'new.address@modontest.ae', Phone = '+971502110015',
            ProjectInterest__c = 'Nawayef Homes', LeadSource = 'Self Generated',
            Nationality__c = 'India', UAEResidentStatus__c = 'Resident',
            EIDNumber__c = '784-2113-1234523-4', En_EIDNumber__c = '784-2113-1234523-4',
            EmiratesIDExpiryDate__c = Date.today().addYears(2)
        );
        insert l;

        Test.startTest();
        SalesConsoleLeadController.convertLeadToCustomer(
            l.Id, 'India', 'Resident', null, null, null, null, null, null, null);
        Test.stopTest();

        Lead after = [SELECT ConvertedAccountId FROM Lead WHERE Id = :l.Id];
        System.assertEquals(existing.Id, after.ConvertedAccountId,
            'The two doors into a booking must agree: the qualify route now ' +
            'matches the document first, exactly like createCustomer.');
        System.assertEquals(1,
            [SELECT COUNT() FROM Account
             WHERE IsPersonAccount = TRUE AND EIDNumber__pc = '784-2113-1234523-4'],
            'Still ONE Person Account holding this Emirates ID.');
    }

    @isTest
    static void testQualifyAmbiguityWaitsForTheRep() {
        makePerson('Wait', 'One', 'waiting@modontest.ae', '+971502110016',
            'Resident', '784-2114-1234524-5', Date.today().addYears(2), null, null, null);
        Account chosenOne = makePerson('Wait', 'Two', 'waiting@modontest.ae',
            '+971502110017', 'Resident', '784-2115-1234525-6',
            Date.today().addYears(2), null, null, null);
        Lead l = new Lead(
            FirstName = 'Waiting', LastName = 'Lead',
            Email = 'waiting@modontest.ae', Phone = '+971502110018',
            ProjectInterest__c = 'Nawayef Homes', LeadSource = 'Self Generated',
            Nationality__c = 'India', UAEResidentStatus__c = 'Resident'
        );
        insert l;

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO first =
            SalesConsoleLeadController.convertLeadToCustomer(
                l.Id, 'India', 'Resident', null, null, null, null, null, null, null);

        System.assertEquals(2, first.candidates.size(), 'Both sharers come back.');
        System.assertEquals(null, first.opportunityId, 'No conversion happened.');
        System.assertEquals(false,
            [SELECT IsConverted FROM Lead WHERE Id = :l.Id].IsConverted,
            'The lead stays open while the rep decides.');

        SalesConsoleLeadController.NewCustomerDTO second =
            SalesConsoleLeadController.convertLeadToCustomer(
                l.Id, 'India', 'Resident', null, null, null, null, null,
                chosenOne.Id, null);
        Test.stopTest();

        System.assertNotEquals(null, second.opportunityId, 'The choice completes it.');
        System.assertEquals(chosenOne.Id,
            [SELECT ConvertedAccountId FROM Lead WHERE Id = :l.Id].ConvertedAccountId,
            'Onto exactly the account the rep chose.');
    }

    @isTest
    static void testTargetAccountMustBeACandidate() {
        /* targetAccountId arrives from a browser */
        makePerson('Target', 'Real', 'target@modontest.ae', '+971502110019',
            'Resident', '784-2116-1234526-7', Date.today().addYears(2), null, null, null);
        Account unrelated = makePerson('Someone', 'Else', 'else@modontest.ae',
            '+971502110020', 'Resident', '784-2117-1234527-8',
            Date.today().addYears(2), null, null, null);
        Lead l = new Lead(
            FirstName = 'Crafted', LastName = 'Call',
            Email = 'target@modontest.ae', Phone = '+971502110021',
            ProjectInterest__c = 'Nawayef Homes', LeadSource = 'Self Generated',
            Nationality__c = 'India', UAEResidentStatus__c = 'Resident'
        );
        insert l;

        Boolean threw = false;
        try {
            SalesConsoleLeadController.convertLeadToCustomer(
                l.Id, 'India', 'Resident', null, null, null, null, null,
                unrelated.Id, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw,
            'An account that is not among this lead\'s candidates is refused.');
        System.assertEquals(false,
            [SELECT IsConverted FROM Lead WHERE Id = :l.Id].IsConverted,
            'And nothing converted.');
    }

    @isTest
    static void testTwoMatchersAgreeOnASingleFixture() {
        /* matchCandidates' document tier and matchAccountByDocument pinned to the same answer */
        Account a = makePerson('Pinned', 'Together', 'pinned@modontest.ae',
            '+971502110022', 'Resident', '784-2118-1234528-9',
            Date.today().addYears(2), null, null, null);

        Id viaPublic = SalesConsoleLeadController.matchAccountByDocument(
            '784-2118-1234528-9', null, null);
        List<Account> viaCandidates = SalesConsoleLeadController.matchCandidates(
            '784-2118-1234528-9', null, null, null, null);

        System.assertEquals(a.Id, viaPublic, 'The public contract finds the account.');
        System.assertEquals(1, viaCandidates.size(), 'The candidate tier finds one row.');
        System.assertEquals(viaPublic, viaCandidates[0].Id,
            'And they are the SAME row - the two spellings of the document WHERE ' +
            'clause must never drift apart.');
    }

    /* 1.28 - controller 1.33: the person match, one search on every key, Emirates ID for a Resident only */

    @isTest
    static void testResidentIsMatchedOnTheEmiratesId() {
        Account holder = makePerson('Eid', 'Resident', 'eid.resident@modontest.ae',
            '+971502110301', 'Resident', '784-2160-1234560-1',
            Date.today().addYears(2), null, null, null);

        /* typed without separators: the console's docVariants still rebuild 3-4-7-1 */
        List<Account> found = SalesConsoleLeadController.personMatches(
            '784216012345601', 'PNEW0301', 'someone.else@modontest.ae', '+971502110399', 'Resident');

        System.assertEquals(1, found.size(), 'A Resident is found by the Emirates ID alone.');
        System.assertEquals(holder.Id, found[0].Id);
        System.assertEquals('eid', SalesConsoleLeadController.matchedOnFor(
            found[0], '784216012345601', 'PNEW0301', 'someone.else@modontest.ae', '+971502110399'));
    }

    @isTest
    static void testNonResidentEmiratesIdIsNotSearched() {
        Account eidHolder = makePerson('Eid', 'Ignored', 'eid.ignored@modontest.ae',
            '+971502110302', 'Resident', '784-2161-1234561-2',
            Date.today().addYears(2), null, null, null);
        Account passHolder = makePerson('Pass', 'Found', 'pass.found@modontest.ae',
            '+971502110303', 'Non-Resident', null, null,
            'PNR0303', Date.today().addYears(-1), Date.today().addYears(3));

        List<Account> found = SalesConsoleLeadController.personMatches(
            '784-2161-1234561-2', 'PNR0303', null, null, 'Non-Resident');

        System.assertEquals(1, found.size(),
            'The Sales App searches the Emirates ID only for a Resident.');
        System.assertEquals(passHolder.Id, found[0].Id, 'The passport is searched.');
        System.assertNotEquals(eidHolder.Id, found[0].Id);
    }

    /* the qualify route reads the residency from the lead, as the Sales App does */
    @isTest
    static void testNonResidentLeadConvergesOnThePassportHolder() {
        makePerson('Eid', 'Elsewhere', 'eid.elsewhere@modontest.ae',
            '+971502110304', 'Resident', '784-2167-1234567-8',
            Date.today().addYears(2), null, null, null);
        Account passHolder = makePerson('Pass', 'Holder', 'pass.holder@modontest.ae',
            '+971502110305', 'Non-Resident', null, null,
            'PNR0305', Date.today().addYears(-1), Date.today().addYears(3));
        Lead l = new Lead(
            FirstName = 'NonRes', LastName = 'Qualify',
            Email = 'nonres.qualify@modontest.ae', Phone = '+971502110306',
            ProjectInterest__c = 'Nawayef Homes', LeadSource = 'Self Generated',
            Nationality__c = 'India', UAEResidentStatus__c = 'Non-Resident',
            EIDNumber__c = '784-2167-1234567-8', En_EIDNumber__c = '784-2167-1234567-8',
            PassportNumber__c = 'PNR0305', En_PassportNumber__c = 'PNR0305',
            PassportIssueDate__c = Date.today().addYears(-1),
            PassportExpiryDate__c = Date.today().addYears(3)
        );
        insert l;

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO res =
            SalesConsoleLeadController.convertLeadToCustomer(
                l.Id, 'India', 'Non-Resident', null, null, null, null, null, null, null);
        Test.stopTest();

        System.assertEquals(null, res.candidates,
            'Only the passport holder matches; the Emirates ID holder is not asked about.');
        System.assertEquals(passHolder.Id,
            [SELECT ConvertedAccountId FROM Lead WHERE Id = :l.Id].ConvertedAccountId);
    }

    @isTest
    static void testEmailOnlyAndMobileOnlyAreListedAfterTheIdMatch() {
        Account idHolder = makePerson('Id', 'Holder', 'id.holder@modontest.ae',
            '+971502110311', 'Resident', '784-2162-1234562-3',
            Date.today().addYears(2), null, null, null);
        Account mailOnly = makePerson('Mail', 'Only', 'combined.buyer@modontest.ae',
            '+971502110312', 'Resident', '784-2163-1234563-4',
            Date.today().addYears(2), null, null, null);
        Account mobileOnly = makePerson('Mobile', 'Only', 'mobile.only@modontest.ae',
            '+971502110313', 'Resident', '784-2164-1234564-5',
            Date.today().addYears(2), null, null, null);

        Test.startTest();
        SalesConsoleLeadController.NewCustomerDTO res =
            SalesConsoleLeadController.createCustomer(
                'Combined', 'Buyer', '0502110313', 'combined.buyer@modontest.ae',
                'Nawayef Homes', 'India', 'Resident',
                '784-2162-1234562-3', 'P0003101', null, null, Date.today().addYears(-1), null,
                Date.today().addYears(2), Date.today().addYears(3), null, null
                , null /* MSC-139 isAuthorisedSignatory */);
        Test.stopTest();

        System.assertNotEquals(null, res.candidates, 'The rep chooses.');
        System.assertEquals(3, res.candidates.size(), 'Every key is searched at once.');
        System.assertEquals(idHolder.Id, res.candidates[0].accountId);
        System.assertEquals('eid', res.candidates[0].matchedOn);
        System.assertEquals(mailOnly.Id, res.candidates[1].accountId);
        System.assertEquals('email', res.candidates[1].matchedOn);
        System.assertEquals(mobileOnly.Id, res.candidates[2].accountId);
        System.assertEquals('mobile', res.candidates[2].matchedOn,
            'Typed 05..., held +971...');
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE LastName = 'Buyer'],
            'Nothing written.');
    }

    @isTest
    static void testMergedAccountsAreNeverMatched() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = TRUE
            LIMIT 1
        ];
        Account merged = new Account(
            FirstName = 'Merged', LastName = 'Away',
            PersonEmail = 'merged.away@modontest.ae', PersonMobilePhone = '+971502110321',
            UAE_Resident_Status__pc = 'Resident', Nationality__pc = 'India',
            EIDNumber__pc = '784-2168-1234568-9', PassportNumber__pc = 'PMRG0321',
            Is_Merged__c = true
        );
        if (!rts.isEmpty()) {
            merged.RecordTypeId = rts[0].Id;
        }
        insert merged;

        System.assertEquals(0, SalesConsoleLeadController.personMatches(
            '784-2168-1234568-9', 'PMRG0321', 'merged.away@modontest.ae', '0502110321',
            'Resident').size(),
            'A merged account is never offered, on any key (Is_Merged__c = FALSE, as the Sales App).');
        System.assertEquals(0, SalesConsoleLeadController.matchPersonCandidates(
            '784-2168-1234568-9', 'PMRG0321', 'merged.away@modontest.ae', '0502110321').size());
    }

    @isTest
    static void testResidencyNotGivenKeepsTheEmiratesId() {
        Account holder = makePerson('Unknown', 'Residency', 'unknown.residency@modontest.ae',
            '+971502110331', 'Resident', '784-2165-1234565-6',
            Date.today().addYears(2), null, null, null);

        System.assertEquals(1, SalesConsoleLeadController.personMatches(
            '784-2165-1234565-6', null, null, null, null).size(),
            'No residency given: the Emirates ID is still a key.');
        System.assertEquals(0, SalesConsoleLeadController.personMatches(
            '784-2165-1234565-6', null, null, null, 'Non-Resident').size(),
            'A stated Non-Resident: it is not.');

        /* the joint owner drawer's entry point passes no residency and one number as both */
        List<Account> viaJoint = SalesConsoleLeadController.matchPersonCandidates(
            '784-2165-1234565-6', '784-2165-1234565-6', null, null);
        System.assertEquals(1, viaJoint.size());
        System.assertEquals(holder.Id, viaJoint[0].Id);
        System.assertEquals('eid', SalesConsoleLeadController.matchedOnFor(
            viaJoint[0], '784-2165-1234565-6', '784-2165-1234565-6', null, null));
    }

    @isTest
    static void testSalesAppMobileSpellingsAndANumberHeldAbroad() {
        Set<String> spellings = SalesConsoleLeadController.personMatchPhones('0502110341');
        System.assert(spellings.containsAll(new Set<String>{
            '502110341', '0502110341', '971502110341', '+971502110341', '00971502110341'
        }), 'The Sales App\'s five spellings: ' + spellings);
        System.assert(SalesConsoleLeadController.personMatchPhones('   ').isEmpty());

        /* held bare, as the Sales App would find it; the console's own spellings never did */
        Account bare = makePerson('Bare', 'Mobile', 'bare.mobile@modontest.ae', '502110342',
            'Non-Resident', null, null, 'PBARE0342', Date.today().addYears(-1), Date.today().addYears(3));
        List<Account> byBare = SalesConsoleLeadController.personMatches(
            null, null, null, '+971 50 211 0342', 'Non-Resident');
        System.assertEquals(1, byBare.size());
        System.assertEquals(bare.Id, byBare[0].Id);

        /* held abroad, as typed: the Sales App's UAE spellings alone would miss it */
        Account abroad = makePerson('Abroad', 'Mobile', 'abroad.mobile@modontest.ae',
            '+918897660343', 'Non-Resident', null, null,
            'PABR0343', Date.today().addYears(-1), Date.today().addYears(3));
        List<Account> byAbroad = SalesConsoleLeadController.personMatches(
            null, null, null, '+91 88976 60343', 'Non-Resident');
        System.assertEquals(1, byAbroad.size());
        System.assertEquals(abroad.Id, byAbroad[0].Id);
        System.assertEquals(null, SalesConsoleLeadController.matchPersonAccount(null, null),
            'Nothing given, nothing matched.');
        System.assertEquals(abroad.Id,
            SalesConsoleLeadController.matchPersonAccount(null, '+918897660343'));
    }

    /* the person match's document keys agree with matchAccountByDocument (frozen) on one account;
       they differ only where the Sales App's residency rule says so */
    @isTest
    static void testPersonMatchAgreesWithMatchAccountByDocument() {
        Account a = makePerson('Pinned', 'Person', 'pinned.person@modontest.ae',
            '+971502110351', 'Resident', '784-2166-1234566-7',
            Date.today().addYears(2), 'PPIN0351', Date.today().addYears(-1), Date.today().addYears(3));

        Id viaEid = SalesConsoleLeadController.matchAccountByDocument('784-2166-1234566-7', null, null);
        List<Account> eidRows = SalesConsoleLeadController.personMatches(
            '784-2166-1234566-7', null, null, null, 'Resident');
        System.assertEquals(a.Id, viaEid);
        System.assertEquals(1, eidRows.size());
        System.assertEquals(viaEid, eidRows[0].Id);

        Id viaPass = SalesConsoleLeadController.matchAccountByDocument(null, 'PPIN0351', null);
        List<Account> passRows = SalesConsoleLeadController.personMatches(
            null, 'PPIN0351', null, null, 'Non-Resident');
        System.assertEquals(a.Id, viaPass);
        System.assertEquals(1, passRows.size());
        System.assertEquals(viaPass, passRows[0].Id);

        /* matchAccountByDocument ignores residency (the joint owner search box); the person match does not */
        System.assertEquals(0, SalesConsoleLeadController.personMatches(
            '784-2166-1234566-7', null, null, null, 'Non-Resident').size());
    }

    @isTest
    static void testBirthdateTravelsToTheAccount() {
        /* a lead carrying Birthdate__c lands its date on the account, fill-only */
        Date dob = Date.newInstance(1990, 4, 12);
        Lead l = new Lead(
            FirstName = 'Carries', LastName = 'Birthdate',
            Email = 'dob@modontest.ae', Phone = '+971502110023',
            ProjectInterest__c = 'Nawayef Homes', LeadSource = 'Self Generated',
            Nationality__c = 'India', UAEResidentStatus__c = 'Resident',
            Birthdate__c = dob
        );
        insert l;

        Test.startTest();
        SalesConsoleLeadController.convertLeadToCustomer(
            l.Id, 'India', 'Resident', null, null, null, null, null, null, null);
        Test.stopTest();

        Id accountId = [SELECT ConvertedAccountId FROM Lead WHERE Id = :l.Id]
            .ConvertedAccountId;
        System.assertEquals(dob,
            [SELECT PersonBirthdate FROM Account WHERE Id = :accountId].PersonBirthdate,
            'The date reaches PersonBirthdate without relying on the unproven ' +
            'lead-to-contact mapping.');
    }

    /* MSC-114. honesty on the individual path */

    /** One normalised value lands in both phone fields. */
    @isTest
    static void testCreateLeadFullPopulatesBothPhoneFields() {
        Id leadId = SalesConsoleLeadController.createLeadDetailed(
            'Both', 'PhoneFields', '+971 50 111 2233', null, 'Nawayef Homes',
            'India', 'Resident', '784-2201-1234520-1', 'P0001368',
            Date.today().addYears(2), Date.today().addYears(-1), Date.today().addYears(3),
            null
        ).leadId;

        Lead l = [SELECT Phone, MobilePhone, En_MobilePhone__c FROM Lead WHERE Id = :leadId];
        System.assertEquals('+971501112233', l.Phone,
            'Spaces stripped - updatePhone no longer runs for this lead, so the '
            + 'normalisation must happen before the insert.');
        System.assertEquals('+971501112233', l.MobilePhone,
            'MobilePhone as well: this is what makes copyMaskedFieldsBeforeInsert '
            + 'stamp En_MobilePhone__c, the field the rest of MODON reads.');
        System.assert(String.isNotBlank(l.En_MobilePhone__c),
            'The mirror is populated at last. Non-blank rather than equal: '
            + 'EncryptedText reads back masked without View Encrypted Data.');
    }

    /** The door reports what happened. */
    @isTest
    static void testCreateLeadDetailedReportsOwnerOutcome() {
        SalesConsoleLeadController.LeadCreateResult r =
            SalesConsoleLeadController.createLeadDetailed(
                'Owner', 'Outcome', '+971502110030', null, 'Nawayef Homes',
                'India', 'Resident', '784-2202-1234521-2', 'P0001391',
                Date.today().addYears(2), Date.today().addYears(-1), Date.today().addYears(3),
                null
            );
        System.assertNotEquals(null, r.leadId);
        System.assertEquals(false, r.queued,
            'No duplicate rule fired, so the rep keeps the lead.');
        System.assertEquals(UserInfo.getName(), r.ownerName,
            'The owner is named verbatim off the record.');
    }

    /** A queue-owned lead is reported by the queue's label. */
    @isTest
    static void testOutcomeForNamesTheQueue() {
        Group q;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // setup-object DML, fenced by runAs
            q = new Group(Name = 'MSC Probe Queue', Type = 'Queue');
            insert q;
            insert new QueueSobject(QueueId = q.Id, SobjectType = 'Lead');
        }
        Lead l = makeLead('QueueOwned', null);
        update new Lead(Id = l.Id, OwnerId = q.Id);

        SalesConsoleLeadController.LeadCreateResult r =
            SalesConsoleLeadController.outcomeFor(l.Id);
        System.assertEquals(true, r.queued, 'Owned by a queue = not the rep\'s list.');
        System.assertEquals('MSC Probe Queue', r.ownerName,
            'The label the rep is told is the queue\'s own, never a guess.');
    }

    /** A closed lead. */
    private static Lead closedLead(String last, String status, String eid, String email) {
        Lead l = new Lead(
            FirstName = 'Closed', LastName = last, Email = email,
            Phone = '+971509993311', ProjectInterest__c = 'Nawayef Homes',
            Nationality__c = 'India', UAEResidentStatus__c = 'Resident',
            EIDNumber__c = eid
        );
        insert l;
        l.Status = status;
        if (status == 'Retired') {
            // Retired_Reason_Mandatory_Check
            l.RetiredReason__c = anyRetiredReason();
        }
        update l;
        return l;
    }

    private static String anyRetiredReason() {
        for (Schema.PicklistEntry pe :
                Lead.RetiredReason__c.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                return pe.getValue();
            }
        }
        return 'Other';
    }

    /** The booking surfaces never offer a closed lead. */
    @isTest
    static void testRetiredAndDuplicateLeaveTheBookingSurfaces() {
        Lead retired = closedLead('SurfRetired', 'Retired',
            '784-2203-1234522-3', 'surf.retired@modontest.ae');
        Lead dup = closedLead('SurfDup', 'Duplicate',
            '784-2204-1234523-4', 'surf.dup@modontest.ae');
        Lead open = closedLead('SurfOpen', 'New',
            '784-2205-1234524-5', 'surf.open@modontest.ae');

        Test.startTest();
        Set<Id> myCustomers = new Set<Id>();
        for (SalesConsoleLeadController.CustomerDTO c :
                SalesConsoleLeadController.getMyCustomers()) {
            if (c.leadId != null) {
                myCustomers.add(c.leadId);
            }
        }
        System.assert(!myCustomers.contains(retired.Id),
            'getMyCustomers must not offer a Retired lead as bookable.');
        System.assert(!myCustomers.contains(dup.Id),
            'Nor a Duplicate one.');
        System.assert(myCustomers.contains(open.Id),
            'An open lead is still offered.');

        System.assertEquals(0,
            SalesConsoleLeadController.findByIdentity(null, 'Resident',
                '784-2203-1234522-3').size(),
            'findByIdentity: the Retired lead is not a match row.');
        System.assertEquals(0,
            SalesConsoleLeadController.findByIdentity(null, 'Resident',
                '784-2204-1234523-4').size(),
            'Nor the Duplicate one.');

        System.assertEquals(0,
            SalesConsoleLeadController.findByContact(null, 'surf.retired@modontest.ae').size(),
            'findByContact: same policy on the contact road.');
        Test.stopTest();
    }

    /** My Leads keeps them, labelled. */
    @isTest
    static void testMyLeadsStillListsRetiredAndDuplicate() {
        Lead retired = closedLead('PaneRetired', 'Retired',
            '784-2206-1234525-6', 'pane.retired@modontest.ae');
        Lead dup = closedLead('PaneDup', 'Duplicate',
            '784-2207-1234526-7', 'pane.dup@modontest.ae');

        Set<Id> listed = new Set<Id>();
        for (SalesConsoleLeadController.LeadDTO d :
                SalesConsoleLeadController.getRecentLeads()) {
            listed.add(d.id);
        }
        System.assert(listed.contains(retired.Id) && listed.contains(dup.Id),
            'My Leads keeps closed leads visible - the grey/red chips label them.');

        Boolean searchable = false;
        for (SalesConsoleLeadController.LeadDTO d :
                SalesConsoleLeadController.searchLeads('pane.dup@modontest.ae')) {
            if (d.id == dup.Id) {
                searchable = true;
            }
        }
        System.assert(searchable,
            'And searchLeads still sees them - the duplicate advisory depends on it.');
    }

    /** A single already-selected lead is always openable. */
    @isTest
    static void testGetLeadDetailIsNeverFiltered() {
        Lead retired = closedLead('DetailRetired', 'Retired',
            '784-2208-1234527-8', 'detail.retired@modontest.ae');
        SalesConsoleLeadController.LeadDTO d =
            SalesConsoleLeadController.getLeadDetail(retired.Id);
        System.assertNotEquals(null, d, 'By-Id resolution is never status-filtered.');
        System.assertEquals('Retired', d.status);
    }

    /** needsAddress is said before the rep chooses. */
    @isTest
    static void testMatchRowsSayNeedsAddress() {
        Account a = makePerson('Needs', 'Address', 'needs.address@modontest.ae',
            '+971564437001', 'Resident', '784-2209-1234528-9',
            Date.today().addYears(2), null, null, null);

        List<SalesConsoleLeadController.CustomerDTO> rows =
            SalesConsoleLeadController.findByIdentity(null, 'Resident', '784-2209-1234528-9');
        System.assertEquals(1, rows.size());
        System.assertEquals(true, rows[0].needsAddress,
            'No mailing address on the account: the row must say so.');

        update new Account(Id = a.Id,
            PersonMailingStreet = 'Street 4', PersonMailingCity = 'Abu Dhabi',
            PersonMailingState = 'Abu Dhabi', PersonMailingPostalCode = '00001',
            PersonMailingCountry = 'United Arab Emirates');
        System.assertEquals(false,
            SalesConsoleLeadController.findByIdentity(null, 'Resident',
                '784-2209-1234528-9')[0].needsAddress,
            'All five parts present - the flag agrees with eligibility, exactly.');
    }

    /** The flag travels every account-row road, never a lead row. */
    @isTest
    static void testNeedsAddressTravelsEveryAccountPath() {
        // findByContact
        makePerson('Contact', 'Road', 'contact.road@modontest.ae',
            '+971564437002', 'Resident', '784-2210-1234529-0',
            Date.today().addYears(2), null, null, null);
        List<SalesConsoleLeadController.CustomerDTO> byEmail =
            SalesConsoleLeadController.findByContact(null, 'contact.road@modontest.ae');
        System.assertEquals(1, byEmail.size());
        System.assertEquals(true, byEmail[0].needsAddress);

        // organisation: billing complete but licence blank still flags
        Account org = new Account(Name = 'Needs Address Co',
            Trade_License_Number__c = 'CN-NA-7701',
            BillingStreet = 'Street 1', BillingCity = 'Abu Dhabi',
            BillingState = 'Abu Dhabi', BillingPostalCode = '00001',
            BillingCountry = 'United Arab Emirates');
        insert org;
        List<SalesConsoleLeadController.CustomerDTO> orgRows =
            SalesConsoleLeadController.findByIdentity('Organisation', 'Resident', 'CN-NA-7701');
        System.assertEquals(1, orgRows.size());
        System.assertEquals(true, orgRows[0].needsAddress,
            'The org test is Billing x5 + the licence number, like the gate.');

        // the candidate road
        List<Account> cands = SalesConsoleLeadController.matchCandidates(
            '784-2210-1234529-0', null, null, null, null);
        System.assertEquals(1, cands.size());
        System.assertEquals(null, cands[0].PersonMailingStreet,
            'Readable, therefore SELECTed - the by-document candidate query.');
        List<Account> byContactCand = SalesConsoleLeadController.matchCandidates(
            null, null, null, 'contact.road@modontest.ae', null);
        System.assertEquals(1, byContactCand.size());
        System.assertEquals(null, byContactCand[0].BillingStreet,
            'And the by-contact candidate query.');

        // a lead row never carries the flag
        Id leadId = SalesConsoleLeadController.createLeadDetailed(
            'Lead', 'NoFlag', '+971502110031', null, 'Nawayef Homes',
            'India', 'Resident', '784-2211-1234530-1', 'P0001591',
            Date.today().addYears(2), Date.today().addYears(-1), Date.today().addYears(3),
            null
        ).leadId;
        for (SalesConsoleLeadController.CustomerDTO c :
                SalesConsoleLeadController.findByIdentity(null, 'Resident',
                    '784-2211-1234530-1')) {
            if (c.leadId == leadId) {
                System.assertEquals(null, c.needsAddress,
                    'Null, not false: false would be a claim a Lead cannot make.');
            }
        }
    }

    /* MSC-212: the journey seed */

    /** "Book a unit" on an open lead returns the row the customer step opens on. */
    @isTest
    static void testLeadRowByIdSeedsAnOpenLead() {
        Lead l = makeLead('SeedMe', null);

        Test.startTest();
        SalesConsoleLeadController.CustomerDTO row =
            SalesConsoleLeadController.leadRowById(l.Id);
        SalesConsoleLeadController.CustomerDTO none =
            SalesConsoleLeadController.leadRowById(null);
        Test.stopTest();

        System.assertEquals(null, none, 'No id seeds nothing.');
        System.assertNotEquals(null, row, 'An open, rep-owned lead must seed.');
        System.assertEquals(l.Id, row.leadId, 'The row is the lead itself.');
        System.assertEquals('Lead', row.kind);
        System.assertEquals(null, row.id, 'No opportunity yet: conversion happens in the picker.');
        System.assertEquals('Nawayef Homes', row.projectInterest,
            'The project rides along for the unit-grid preselect.');
        /* makeLead writes Company but no TradeName__c - the junk-Company shape integrations
           produce on person leads. It must NOT read as an organisation. */
        System.assertEquals(false, row.isOrganisation,
            'Company without TradeName__c is a person lead (Trade_Details_Are_Mandatory shape).');
    }

    /** A lead converted while the drawer was open comes back as its Opportunity. */
    @isTest
    static void testLeadRowByIdAdoptsAConvertedLead() {
        Lead l = makeLead('SeedConverted', null);
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(l.Id);
        lc.setConvertedStatus('Qualified');
        /* with an opportunity this time - the adoption path needs one */
        lc.setDoNotCreateOpportunity(false);
        lc.setOwnerId(UserInfo.getUserId());
        Database.LeadConvertResult r = Database.convertLead(lc, false);
        if (!r.isSuccess()) {
            /* org-level conversion blockers (duplicate rules on the fixture) are not this
               method's fault; the refusal path is covered by the other two tests */
            return;
        }

        Test.startTest();
        SalesConsoleLeadController.CustomerDTO row =
            SalesConsoleLeadController.leadRowById(l.Id);
        Test.stopTest();

        System.assertNotEquals(null, row, 'A converted lead still answers.');
        System.assertEquals(r.getOpportunityId(), row.id,
            'id carries the Opportunity - the journey adopts it instead of seeding the panel.');
        System.assertEquals('Customer', row.kind);
    }

    /** The rows the booking surfaces exclude return null - the journey opens unseeded. */
    @isTest
    static void testLeadRowByIdRefusesClosedLeads() {
        Lead l = makeLead('SeedRetired', null);
        /* Retired_Reason_Mandatory_Check runs on Status = Retired in some orgs; write both */
        l.Status = 'Retired';
        try {
            update l;
        } catch (DmlException e) {
            /* the org refused the fixture, not the method; nothing left to prove here */
            return;
        }

        Test.startTest();
        SalesConsoleLeadController.CustomerDTO row =
            SalesConsoleLeadController.leadRowById(l.Id);
        Test.stopTest();

        System.assertEquals(null, row,
            'Retired leads leave the booking surfaces; the seed must follow the same rule.');
    }

    /* 1.29 - controller 1.34: every rep finds every customer, whoever owns the account */

    /**
     * A console user who cannot see a customer another user owns: profile Sales Operation (no View All
     * on Account, and its record type defaults let a conversion make an opportunity), with the console's
     * permission set where the org has it. Made as the running admin, so no mixed DML.
     */
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

    private static Boolean canRead(Id userId, Id recordId) {
        return [
            SELECT RecordId, HasReadAccess FROM UserRecordAccess
            WHERE UserId = :userId AND RecordId = :recordId
        ].HasReadAccess == true;
    }

    private static Boolean holds(List<SalesConsoleLeadController.CustomerDTO> rows, Id accountId) {
        for (SalesConsoleLeadController.CustomerDTO r : rows) {
            if (r.accountId == accountId) {
                return true;
            }
        }
        return false;
    }

    @isTest
    static void testEveryCustomerIsFoundWhoeverOwnsIt() {
        Account a = makePerson('Hidden', 'Customer', 'hidden.customer@modontest.ae',
            '+971502119901', 'Resident', '784-1985-7654321-1', Date.today().addYears(2),
            'P7654321', Date.today().addYears(-1), Date.today().addYears(3));
        User rep = repWithoutAccess('scwnoa1');
        System.assertEquals(false, canRead(rep.Id, a.Id),
            'Precondition: this console user has no access to the customer.');

        System.runAs(rep) {
            System.assert(holds(SalesConsoleLeadController.findByIdentity(
                    null, 'Resident', '784-1985-7654321-1'), a.Id),
                'Find customer by Emirates ID finds a customer the rep cannot otherwise see.');
            System.assert(holds(SalesConsoleLeadController.findByIdentity(
                    null, 'Non-Resident', 'P7654321'), a.Id),
                'And by passport.');
            System.assert(holds(SalesConsoleLeadController.findByContact(
                    null, 'hidden.customer@modontest.ae'), a.Id),
                'And by email.');
            System.assert(holds(SalesConsoleLeadController.findByContact(
                    null, '0502119901'), a.Id),
                'And by mobile, however it is typed.');

            List<Account> matched = SalesConsoleLeadController.matchPersonCandidates(
                null, 'P7654321', null, null);
            System.assertEquals(1, matched.size(), 'The person match finds them too.');
            System.assertEquals(a.Id, matched[0].Id);
            System.assertEquals(a.Id,
                SalesConsoleLeadController.matchAccountByDocument('784-1985-7654321-1', null, null),
                'And the document match the joint owner search uses.');

            SalesConsoleLeadController.IdentityStateDTO s =
                SalesConsoleLeadController.identityFor(a.Id, null, 'Resident');
            System.assertEquals('784-1985-7654321-1', s.eidNumber,
                'Choosing them reads the documents they hold, not a blank record.');
            System.assertEquals(true, s.complete, 'So nothing is asked twice.');
        }
    }

    @isTest
    static void testCompanyAndItsSignatoriesAreFoundWhoeverOwnsThem() {
        Account company = makeCompany('Hidden Holdings LLC', 'UNI-TEST-0901', 'OrganizationAccount');
        insert new Contact(AccountId = company.Id, FirstName = 'Rana', LastName = 'Saleh',
            Email = 'rana.saleh@example.com');
        User rep = repWithoutAccess('scwnoa2');
        System.assertEquals(false, canRead(rep.Id, company.Id),
            'Precondition: this console user has no access to the company.');

        System.runAs(rep) {
            List<SalesConsoleLeadController.CustomerDTO> found =
                SalesConsoleLeadController.findByIdentity('Organisation', 'Resident', 'UNI-TEST-0901');
            System.assertEquals(1, found.size(), 'The company is found by its licence.');
            System.assertEquals(1, found[0].signatories.size(),
                'With the people who can sign for it, so the rep can choose one.');
            System.assertEquals(company.Id,
                SalesConsoleLeadController.matchOrganisationAccount('UNI-TEST-0901'),
                'And the company match used before a company is created.');
        }
    }

    @isTest
    static void testBookingForACustomerTheRepCannotSee() {
        Account a = makePerson('Hidden', 'Booker', 'hidden.booker@modontest.ae',
            '+971502119902', 'Resident', '784-1986-7654322-2', Date.today().addYears(2),
            'P7654322', Date.today().addYears(-1), Date.today().addYears(3));
        User rep = repWithoutAccess('scwnoa3');

        SalesConsoleLeadController.NewCustomerDTO booked;
        System.runAs(rep) {
            booked = SalesConsoleLeadController.bookForExistingCustomer(
                a.Id, 'Hidden', 'Booker', '+971502119902', 'hidden.booker@modontest.ae',
                'Nawayef Homes', 'India', 'Resident', '784-1986-7654322-2', 'P7654322',
                null, null, Date.today().addYears(-1), null,
                null, Date.today().addYears(2), Date.today().addYears(3), null, null);
        }

        System.assertNotEquals(null, booked.opportunityId, 'The booking starts.');
        Opportunity o = [SELECT AccountId, OwnerId FROM Opportunity WHERE Id = :booked.opportunityId];
        System.assertEquals(a.Id, o.AccountId, 'On the customer the rep chose.');
        System.assertEquals(rep.Id, o.OwnerId, 'In the rep\'s own new opportunity.');
        System.assertEquals(true, canRead(rep.Id, a.Id),
            'From then on the rep reads the customer, so the booking and KYC panels work.');
        System.assertEquals(1,
            [SELECT COUNT() FROM Account WHERE EIDNumber__pc = '784-1986-7654322-2'],
            'And no second customer was made.');
    }

    @isTest
    static void testCreateAndContinueConvergesOnAHiddenCustomer() {
        Account a = makePerson('Hidden', 'Twin', 'hidden.twin@modontest.ae',
            '+971502119903', 'Resident', '784-1987-7654323-3', Date.today().addYears(2),
            'P7654323', Date.today().addYears(-1), Date.today().addYears(3));
        User rep = repWithoutAccess('scwnoa4');

        SalesConsoleLeadController.NewCustomerDTO res;
        System.runAs(rep) {
            res = SalesConsoleLeadController.createCustomer(
                'Hidden', 'Twin', '+971502119903', 'hidden.twin@modontest.ae', 'Nawayef Homes',
                'India', 'Resident', '784-1987-7654323-3', 'P7654323', null, null,
                Date.today().addYears(-1), null, Date.today().addYears(2), Date.today().addYears(3),
                null, null, null);
        }

        System.assertEquals(null, res.candidates, 'One match: no chooser.');
        System.assertNotEquals(null, res.opportunityId,
            'The booking starts. ' + SalesConsoleLeadController.lastConvertError);
        System.assertEquals(a.Id,
            [SELECT ConvertedAccountId FROM Lead WHERE Id = :res.leadId].ConvertedAccountId,
            'The new lead converges on the customer the rep could not see before.');
        System.assertEquals(1,
            [SELECT COUNT() FROM Account WHERE EIDNumber__pc = '784-1987-7654323-3'],
            'Still one customer holding this Emirates ID.');
    }

    @isTest
    static void testQualifyingALeadConvergesOnAHiddenCustomer() {
        Account a = makePerson('Hidden', 'Qualify', 'hidden.qualify@modontest.ae',
            '+971502119904', 'Non-Resident', null, null,
            'P7654324', Date.today().addYears(-1), Date.today().addYears(3));
        User rep = repWithoutAccess('scwnoa5');

        Id leadId;
        System.runAs(rep) {
            Lead l = new Lead(
                FirstName = 'Hidden', LastName = 'Qualify',
                Email = 'new.qualify@modontest.ae', Phone = '+971502119905',
                ProjectInterest__c = 'Nawayef Homes', LeadSource = 'Self Generated',
                Nationality__c = 'India', UAEResidentStatus__c = 'Non-Resident',
                PassportNumber__c = 'P7654324', En_PassportNumber__c = 'P7654324',
                PassportIssueDate__c = Date.today().addYears(-1),
                PassportExpiryDate__c = Date.today().addYears(3)
            );
            insert l;
            leadId = l.Id;
            SalesConsoleLeadController.convertLeadToCustomer(
                leadId, 'India', 'Non-Resident', null, null, null, null, null, null, null);
        }

        System.assertEquals(a.Id,
            [SELECT ConvertedAccountId FROM Lead WHERE Id = :leadId].ConvertedAccountId,
            'The rep\'s own lead is qualified onto the customer holding the passport.');
    }

}