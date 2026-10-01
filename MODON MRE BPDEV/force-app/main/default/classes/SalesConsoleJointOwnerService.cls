/**
 * The joint owners on a booking, and every rule that governs them.
 *
 * Version  Author      Date         Detail
 * 2.4      Aurelix Dev 29 Sep 2026  Every rep finds every customer as a joint owner too, as a buyer
 *                                   (SalesConsoleLeadController 1.34): loadPerson reads the found account
 *                                   without sharing (PersonLookup); the party list and writes keep sharing.
 * 2.3      Aurelix Dev 29 Sep 2026  Nationality__pc and UAE_Resident_Status__pc are restricted picklists:
 *                                   resolveOrCreatePerson and fillBlankContactDetails match the value to the
 *                                   field's active values and refuse anything else before any DML.
 * 2.2      Aurelix Dev 28 Sep 2026  Two changes asked on 28 Sep. (1) A new person is matched
 *                                   as a buyer is before one is created: resolveOrCreatePerson runs
 *                                   SalesConsoleLeadController.matchPersonCandidates (the buyer's
 *                                   chooser rule: Emirates ID or passport first, then email or mobile
 *                                   with the UAE spellings, merged accounts left out). Any match stops
 *                                   the create: createPerson returns the matches for the rep to choose
 *                                   from (PersonDTO.matches) and writes nothing; addOwner refuses. Creating
 *                                   anyway (AddOwnerInput.createDespiteMatch) needs
 *                                   ALLOW_NEW_CUSTOMER_DESPITE_MATCH (AurelixNewCustomerSwitch), and is
 *                                   refused in the Sales App's words while it is off. This replaces the
 *                                   silent reuse of 1.9 (a document match, or one email or mobile match).
 *                                   (2) partyProblem, the guard the joint owner's manual KYC route uses
 *                                   (AurelixManualKycService, AurelixKycDocumentService): a person already
 *                                   on this booking, or one who could be added to it now.
 * 2.1      Aurelix Dev 22 Sep 2026  MODON now checks a joint owner's KYC when the row is inserted
 *                                   (MODON's JointOwnerTriggerHelper 2.0), so a person without
 *                                   KYC can no longer be added. The search result now says whether
 *                                   the person passes that same check (applyKyc), checkPerson asks
 *                                   again, sendCandidateVerification sends a KYC link to a person
 *                                   who is not on the booking yet, and createPerson creates a new
 *                                   person without adding them, so they can do KYC first.
 * 1.x      Aurelix Dev  18 Sep 2026  PartyDTO.manuallyApproved; the buyer, owner and person queries
 *                                    carry Manual_KYC_Approval__c so a manual approval reads as
 *                                    verified on the Verification track (see VerificationService).
 * 2.0      Aurelix Dev 30 Aug 2026  MSC-180. COMPANIES, ON BOTH SIDES OF THE TABLE.
 *                                   Two openings, one record-authoritative rule set.
 *                                   (a) A CORPORATE BUYER no longer blocks the panel:
 *                                   resolve() carries on, buyerIsCompany rides the DTO,
 *                                   and every per-party gate already answered for a
 *                                   company (canEverVerify, applyCompliance) does the
 *                                   talking. The signatory fallback that was always
 *                                   there (PrimaryContact__c) is the "not the buyer"
 *                                   comparison. (b) A COMPANY JOINT OWNER can be
 *                                   searched (matchOrganisationAccount - person match
 *                                   first, so no person resolves differently), linked,
 *                                   or created (Name + trade licence into the SAME
 *                                   three licence fields companyUpdate writes, org
 *                                   record type). The RECORD decides which rules
 *                                   apply, never the browser's flag: a crafted
 *                                   accountId lands in checkCompanyIsUsable, which
 *                                   refuses merged and non-customer record types.
 *                                   Company relationship is Partner/Third Party only.
 *                                   Duplicates re-keyed by Account Id as well as
 *                                   contact - MODON's trigger skips companies in its
 *                                   own duplicate and six-cap checks, so ours is the
 *                                   only fence they have. personRecordTypeId now takes
 *                                   the buyer's record type ONLY from a person buyer:
 *                                   under a corporate buyer it handed the ORG record
 *                                   type to a newly created individual co-owner.
 *                                   Out of scope, parked with the client: SendEnvelope
 *                                   refuses the whole envelope while any joint owner
 *                                   has no personal resident status, which is every
 *                                   company - Sales Operations' path, unchanged here.
 * 1.10     Aurelix Dev 25 Aug 2026  MSC-178. A co-owner's document lands in ONE field.
 *                                   The drawer sends the rep's single number as both
 *                                   eidNumber and passportNumber - correct, the rep
 *                                   should not have to know which box it belongs in -
 *                                   and resolveOrCreatePerson was meant to choose.
 *                                   It did not: it wrote both, so every co-owner
 *                                   created here carries the same string as an
 *                                   Emirates ID AND as a passport. Two DEV_1 accounts
 *                                   hold the damage. Fifteen digits is an Emirates ID
 *                                   (the UAE 3-4-7-1 format, the same rule
 *                                   SalesConsoleLeadController.docVariants uses);
 *                                   anything else is a passport. The SEARCH still
 *                                   passes both and reads both fields - only the write
 *                                   narrows.
 * 1.9      Aurelix Dev 25 Aug 2026  MSC-172. resolveOrCreatePerson asks a second
 *                                   question before it inserts. The document search was
 *                                   the only one it had, so a co-owner the org already
 *                                   held under an email or a mobile - and no document -
 *                                   got a duplicate Person Account every time, with no
 *                                   chooser in the way and no race required. Through
 *                                   SalesConsoleLeadController.matchPersonAccount, which
 *                                   answers null on ambiguity as well as on nothing
 *                                   found, so a shared mailbox never quietly decides who
 *                                   signs a contract. Runs only where the document
 *                                   search found nobody: no booking that resolves today
 *                                   resolves differently.
 * 1.8      Aurelix Dev 22 Aug 2026  MSC-115. The corporate sentence is the one the
 *                                   verification step now tells - a company is proved by
 *                                   the signed KYC and Wealth Form and by Passfort, not by
 *                                   a link nobody can send.
 * 1.0      Aurelix IT  20 Aug 2026  Initial. MSC-080. Phase 1 of the joint owner
 *                                   module: the server side, with no UI.
 * 1.1      Aurelix IT  20 Aug 2026  MSC-081. WORDING ONLY - no logic, no signature and
 *                                   no guard behaviour changed. Every sentence here is
 *                                   rendered VERBATIM by c/mscOwners, so they have to
 *                                   speak Modon's vocabulary or the panel contradicts
 *                                   itself from 40px away - "Ownership %" as the field
 *                                   label and "share" in the error underneath it.
 *                                   buyer -> primary owner, share -> Ownership %,
 *                                   contract -> SPA, relationship -> Relationship Type
 *                                   and Relationship Sub Type. The words now match the
 *                                   Joint Owners related list the rep opens next.
 * 1.2      Aurelix IT  20 Aug 2026  MSC-082. IDENTITY VERIFICATION, PER PERSON. Every
 *                                   party's own KYC state is read back onto PartyDTO and
 *                                   sendVerification puts one person into MODON's Signzy
 *                                   pipeline - which has taken an Account Id all along.
 *                                   Two things the live data forced. First,
 *                                   sendKYCForm demands nationality, residency, email and
 *                                   mobile, and phase 1 requires none of them, so 94.8% of
 *                                   the joint owners in DEV_1 cannot be sent anything: the
 *                                   DTO now carries WHY, and updateOwner can fill those
 *                                   fields - BLANK ONES ONLY, never an overwrite. Second,
 *                                   127 of 135 joint owner accounts are company accounts,
 *                                   which that pipeline refuses outright, so they are
 *                                   reported as unverifiable rather than offered a button
 *                                   that would do nothing.
 * 1.3      Aurelix IT  20 Aug 2026  MSC-083. COMPLIANCE, PER PERSON - the state only.
 *                                   complianceSubmitted and complianceStatus were
 *                                   declared in 1.2 and half-filled: they read
 *                                   PassfortApprovalStatus__pc alone, where the compliance
 *                                   service has always known THREE independent ways of
 *                                   telling - an approval status, a Passfort profile id,
 *                                   or an open PassfortTransaction__c - because any one of
 *                                   them can be true on its own. A person already in
 *                                   flight read as "not sent". Now one definition, and one
 *                                   query for the whole panel rather than one per person.
 *                                   canCheckCompliance mirrors the gates
 *                                   SalesConsoleComplianceService.resolve keeps, so the
 *                                   row never offers a check the server would refuse.
 *                                   The correction to 1.2's own note: 127 of 135 is ROWS.
 *                                   DEV_1 has 7 distinct joint owner accounts and one
 *                                   company account sits on 127 orders - per person it is
 *                                   1 in 7, not 94%. The behaviour was right either way.
 * 1.4      Aurelix IT  20 Aug 2026  MSC-084. THREE THINGS THE BACK CATALOGUE SAYS AND
 *                                   THE JOURNEY NEVER COULD. The panel reaches My
 *                                   Bookings in this phase, and My Bookings lists every
 *                                   order the rep owns - cancelled and voided ones
 *                                   deliberately included. Seven of the fourteen orders
 *                                   in DEV_1 that carry a joint owner are dead, and one
 *                                   carries 64 rows for one person on one unit. None of
 *                                   that is reachable from the journey, which is exactly
 *                                   why it survived. (a) A booking whose every unit is
 *                                   cancelled was told "This booking has no confirmed
 *                                   unit yet", which is not what happened to it.
 *                                   (b) unitNames was appended once per ROW, so that
 *                                   64-row record would have printed one unit name
 *                                   sixty-six times. (c) onAllUnits compared row count
 *                                   to unit count - the same rows-not-people mistake
 *                                   this file's own 1.3 note corrects for the tally.
 *                                   Plus partyCount, so a host can label a tab without
 *                                   opening the panel. No guard, no signature and no
 *                                   refusal sentence changed.
 * 1.7      Aurelix Dev 20 Aug 2026  MSC-094. WORDING ONLY. A booking nobody co-owns no
 *                                   longer gets a coverage sentence. "None of the 2
 *                                   units has a joint owner yet" was true of every
 *                                   sole-owned booking, so it appeared on all of them
 *                                   and reported the ordinary case as a shortfall. No
 *                                   guard, no signature and no refusal changed.
 *
 * A joint owner is a second (third, fourth) buyer on the same unit - a co-owner with a
 * percentage of the property, not a related contact. The console has never had them, so a
 * booking it makes for a couple is incomplete by construction: the second person never
 * reaches Passfort, never signs the SPA and never gets portal access, while the same
 * booking made in classic Salesforce would. Roughly one booking in eight is affected.
 *
 * THIS IS THE ONLY THING IN THE CONSOLE ALLOWED TO WRITE A JointOwner__c. Every rule
 * lives here, and every one of them runs before any DML. A screen's disabled button is a
 * hint; this class is the gate, and it is the only one that counts.
 *
 * WE WRITE THE JUNCTION AND NOTHING ELSE. SalesOrder__c.JO1__c..JO6__c, the ownership
 * mirrors, Number_of_JointOwners__c and JointOwner_Status__c are all output of MODON's
 * JointOwnerTriggerHelper. Writing them here would make two authors of one field and they
 * would drift the first time either changed. Opportunity__c is not set either - the
 * before-save Flow Joint_Owner_Before_Created_Updated stamps it from the Sales Order, and
 * it runs before any before-trigger we could add.
 *
 * WHY THE SALES ORDER AND NOT THE OPPORTUNITY. Three reasons, in order of weight. It is
 * what every downstream reader traverses (SalesOrder__c.Joint_Owners__r drives the SPA
 * recipients, the portal, the letters and eight batch jobs). It is when the work actually
 * happens - 96.8% of joint owners in the last twelve months were created at or after the
 * Sales Order, 59.3% of them after. And it is the only parent under which MODON's own
 * 100% rule fires at all: checkOwnershipPercentage queries
 * "Opportunity__c IN :oppIds AND SalesOrder__c IN :soId", so a row carrying only an
 * Opportunity is never validated.
 *
 * THE GUARDS SEE MORE THAN THE REP DOES, DELIBERATELY. JointOwner__c is org-wide Private
 * and the SalesTeamSharing rule grants Read but not Edit, so a rep can be shown a booking
 * whose joint owners they cannot all see. The party list is therefore built UNDER sharing
 * - the rep sees what they are entitled to - while the counts, share totals and duplicate
 * check that decide a refusal are taken WITHOUT sharing, because a guard that cannot see
 * a record is not a guard. It would wave through a seventh owner or a duplicate and leave
 * MODON's trigger to refuse it, on the wrong record, in words no rep can act on. Nothing
 * read that way is ever rendered: it produces refusals and one count.
 *
 * WHAT IT DOES NOT DO. It never removes a joint owner - that is a Service Request, by the
 * client's decision, and MODON's afterDeleteMethod is empty so a delete would leave
 * JO1__c..JO6__c pointing at the removed person. It never accepts a company as a joint
 * owner. It never touches a Modon Egypt booking, which has its own screen. And it never
 * writes a joint owner to a booking whose contract has gone out for signature.
 */
public with sharing class SalesConsoleJointOwnerService {

    /**
     * A Sales Order in one of these is not a booking to write an owner onto.
     *
     * COMPARED LOWERCASED, and that is not fussiness. The org stores 'System cancelled'
     * with a lower-case c while every hand-written set in this codebase spells it
     * 'System Cancelled', and Set<String>.contains is case-sensitive - so the usual
     * spelling silently treats a system-cancelled order as live.
     *
     * Deliberately broader than SalesConsoleComplianceService.DEAD_ORDERS, which omits
     * the two SR statuses (905 orders in preprod). The asymmetry is the safe direction:
     * every order this class refuses to write to, that class also refuses to submit,
     * never the other way round.
     */
    private static final Set<String> DEAD_ORDERS = new Set<String>{
        'cancelled',
        'system cancelled',
        'voided',
        'cancelled sr',
        'property transfer cancelled - sr'
    };

    /**
     * The SPA has not left the building. A null SPAStatus__c counts as open - 1,560
     * preprod orders have never started the SPA process at all.
     */
    private static final Set<String> SPA_OPEN = new Set<String>{
        'SPA Not Generated',
        'SPA Generated'
    };

    /**
     * Open, but the document is now stale.
     *
     * The SPA has been produced with the current owner list merged into it. Nothing has
     * gone to the customer, so it can be regenerated - and 17 joint owners live on such
     * orders today, so refusing would be stricter than the business behaves. The write
     * succeeds and says so.
     */
    private static final String SPA_WARN = 'SPA Generated';

    /**
     * Status__c values that mean the SPA went out, whatever SPAStatus__c claims.
     *
     * A third signal for one question, because the first two disagree with each other on
     * live data: two preprod orders read a signed status here while SPAStatus__c still
     * says the SPA was never generated, and one of them carries a joint owner. Any one
     * signal closes the gate.
     */
    private static final Set<String> STATUS_SPA_OUT = new Set<String>{
        'SPA Sent to customer',
        'SPA Signed (Customer)',
        'SPA Signed (Modon)',
        'SPA Delivered',
        'SPA Validated',
        'Completed'
    };

    /** Egypt is a different product with its own Add Joint Owners screen. */
    private static final String EGYPT = 'Modon - Egypt';

    /** JO1__c..JO6__c is the ceiling, structurally and in MODON's trigger. */
    private static final Integer MAX_OWNERS = 6;

    /* 1.6 - MSC-091. Why a joint owner's details can no longer be changed here. Both
       sentences say what happened and what it means, never just "not allowed". */
    private static final String EDIT_NOT_YOURS =
        'This joint owner was added by another user, so their details cannot be '
        + 'changed here.';

    private static String editSentReason(String name) {
        String who = String.isBlank(name) ? 'This joint owner' : name;
        return who + ' has already been sent an identity verification link, so their '
            + 'details can no longer be changed here. Raise a service request if they '
            + 'have to be corrected.';
    }

    /**
     * How many units one call may write.
     *
     * Each JointOwner__c insert fires updateJO, which updates the Sales Order - two DML
     * statements per unit, plus the Sales Order's own trigger chain on top. Ten units is
     * 21 statements with the account insert, comfortably inside the limit, and the
     * caller is told what was deferred rather than meeting a limit exception. The
     * fourteen-unit basket is one booking in 2,236.
     */
    private static final Integer MAX_UNITS_PER_WRITE = 10;

    private static final String PERSON_RT = 'PersonAccount';
    /* 2.0 - MSC-180. The record type the org's own company customers carry - 43 of
       DEV_1's corporate buyers and 10 of UAT's 12 company joint owners - and the one
       a company created here gets. */
    private static final String ORG_RT = 'OrganizationAccount';
    /* The two relationship types that can describe a company. The picklist's other
       values are kinship, and Sales Operations' own back-door rows prove what happens
       without a fence: preprod holds company joint owners filed as Friend and Father. */
    private static final Set<String> COMPANY_REL_TYPES =
        new Set<String>{ 'Partner', 'Third Party' };
    private static final String SERVICE_REQUEST_ROUTE =
        'it must now go through a Joint Owner Addition service request.';

    // ======================================================================
    // DTOs
    // ======================================================================

    /** One unit of this booking, and whether an owner can still be added to it. */
    public class UnitDTO {
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String bookingRef;
        @AuraEnabled public Id unitId;
        @AuraEnabled public String unitName;
        @AuraEnabled public String status;
        /** False once the contract has gone out. The panel renders it read only. */
        @AuraEnabled public Boolean open = false;
        /** Why it is closed, in words a rep can act on. Null when open. */
        @AuraEnabled public String closedReason;
        /** Open, but the SPA is now stale. Null when there is nothing to say. */
        @AuraEnabled public String warning;
        @AuraEnabled public Integer ownerCount = 0;
        @AuraEnabled public Decimal allocatedShare = 0;
        @AuraEnabled public Integer slotsRemaining = 6;
        /**
         * Owners on this unit the running user is not allowed to see. Reported rather
         * than hidden: a list that is quietly short is worse than one that says so.
         */
        @AuraEnabled public Integer hiddenOwnerCount = 0;
    }

    /** Where one person stands on one unit. */
    public class HoldingDTO {
        @AuraEnabled public Id jointOwnerId;
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String unitName;
        @AuraEnabled public Decimal share;
        @AuraEnabled public Datetime addedOn;
        /** False when sharing will not let this rep change the row. */
        @AuraEnabled public Boolean editable = false;
    }

    /** One person on this booking. The buyer is a party too, not a heading. */
    public class PartyDTO {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id personContactId;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean isPrimary = false;
        @AuraEnabled public String relationshipType;
        @AuraEnabled public String relationshipSubType;
        @AuraEnabled public String residentStatus;
        @AuraEnabled public String nationality;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public List<HoldingDTO> holdings = new List<HoldingDTO>();
        /** Their share on the focused unit, or on the only unit. */
        @AuraEnabled public Decimal share;
        /** Which units they are on, by name, for the row's summary line. */
        @AuraEnabled public List<String> unitNames = new List<String>();
        /** True when they are on every open unit of this booking. */
        @AuraEnabled public Boolean onAllUnits = false;
        /* 1.2 - identity verification, per person. Every one of them goes through
           Signzy separately, against their own Account, so all of this is read from
           that person's record and never inherited from the booking. */
        /** NOT_SENT | SENDING | SENT | EXPIRED | VERIFIED. Never IN_BRANCH - see
            SalesConsoleVerificationService.statusForParty for why that stays buyer-only. */
        @AuraEnabled public String verificationStatus;
        /** 18 Sep 2026 - identity approved manually (no completion date); shown as the verified fact. */
        @AuraEnabled public Boolean manuallyApproved = false;
        @AuraEnabled public Date kycCompletedDate;
        /** When their link went out. Null until one has. */
        @AuraEnabled public Datetime verificationSentOn;
        /** Whether a link can be sent to them AT ALL, right now. */
        @AuraEnabled public Boolean canSendVerification = false;
        /** Why not, in words the rep can act on. Null when they can. */
        @AuraEnabled public String verificationBlockedReason;
        /**
         * True when the ONLY thing in the way is contact detail the console can
         * collect - and therefore when the row should offer to collect it rather than
         * print a reason and stop. False for a company account, which no amount of
         * typing makes verifiable here.
         */
        @AuraEnabled public Boolean detailsMissing = false;
        /** False for a company account: outside the Signzy route entirely. */
        @AuraEnabled public Boolean canEverVerify = false;
        /* 2.0 - MSC-180. True when this party is a company account. The drawer hides
           the person-only sections (contact fill, residency) behind it and the table
           needs nothing: every fact it prints is already null-tolerant. */
        @AuraEnabled public Boolean isCompany = false;
        /* 1.3 - compliance, per person. Same reason: Passfort profiles are per human
           being, not per booking, so every one of these is read off that person's own
           Account and nothing is inherited from the deal. */
        /** True on ANY of the three ways of knowing. See applyCompliance. */
        @AuraEnabled public Boolean complianceSubmitted = false;
        /** PassfortApprovalStatus__pc, raw. The panel translates it, once, its own way. */
        @AuraEnabled public String complianceStatus;
        /** Whether their compliance check can be opened at all, right now. */
        @AuraEnabled public Boolean canCheckCompliance = false;
        /**
         * 1.6 - MSC-091. Whether this person's ownership row can still be changed
         * from the console, and the sentence to show when it cannot.
         *
         * Decided here rather than in the browser because it is the same question
         * updateOwner answers on the write, and two copies of it are how a screen and
         * a server come to disagree. Three things close it: the booking is past the
         * point where owners change at all, the row belongs to another user, or an
         * identity verification link has already gone to this person. The last is the
         * new one - once a link is out, the details it was sent against are what the
         * customer is verifying, and changing them underneath a live verification
         * leaves the record and the check describing two different people.
         *
         * The primary owner is never editable here for a different reason entirely:
         * their share is 100 less the others and is not a settable field.
         */
        @AuraEnabled public Boolean canEdit = false;
        @AuraEnabled public String editBlockedReason;
        /** Why not, in words the rep can act on. Null when it can. */
        @AuraEnabled public String complianceBlockedReason;
    }

    /** Everything the panel needs, in one answer. */
    public class OwnersDTO {
        @AuraEnabled public Boolean available = false;
        @AuraEnabled public String blockedReason;
        /** True when no unit of this booking will accept an owner any more. */
        @AuraEnabled public Boolean readOnly = false;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Id focusedSalesOrderId;
        @AuraEnabled public List<UnitDTO> units = new List<UnitDTO>();
        @AuraEnabled public List<PartyDTO> parties = new List<PartyDTO>();
        /** 100 less what the joint owners hold on the focused unit. */
        @AuraEnabled public Decimal primaryShare = 100;
        @AuraEnabled public Integer slotsRemaining = 6;
        @AuraEnabled public Integer jointOwnerCount = 0;
        @AuraEnabled public Boolean isMultiUnit = false;
        /* 2.0 - MSC-180. True when the BUYER is a company account. The pane reads it
           to keep loading the company's two verification tracks now that `available`
           is true for a corporate booking - the old signal, available !== true, is
           exactly what this opening takes away. */
        @AuraEnabled public Boolean buyerIsCompany = false;
        /* 1.2 - the verification tally the head chip reads.
           The DENOMINATOR IS PEOPLE WHO COULD EVER VERIFY, not everyone on the booking:
           a company joint owner is outside the Signzy route, so counting them would
           produce a fraction that can never reach its own denominator and a rep who
           chases a person nobody can send anything to. Their row says so instead. */
        @AuraEnabled public Integer verifiedCount = 0;
        @AuraEnabled public Integer verifiableCount = 0;
        /* 1.3 - and how many of those same people have reached compliance. The
           DENOMINATOR IS DELIBERATELY verifiableCount and not a second population: they
           are the same people, counted the same way, by Account and not by row. Two
           fractions with two denominators on one panel would invite the rep to work out
           which one they were looking at. */
        @AuraEnabled public Integer complianceSubmittedCount = 0;
        /** Units of this booking with no joint owner at all, by name. */
        @AuraEnabled public List<String> unitsWithNoJointOwner = new List<String>();
        /**
         * The coverage sentence, built here rather than in the LWC.
         *
         * It is a claim about data, so it is computed where the data is. It is also
         * permanent, not a validation that appears on failure: a screen that only speaks
         * up when it thinks something is wrong cannot be trusted when it is silent, and
         * silence is exactly how 36% of multi-unit bookings ended up with a unit nobody
         * co-owns.
         */
        @AuraEnabled public String coverageLine;
        /** Set after a write when something succeeded but is worth saying. */
        @AuraEnabled public String warning;
        /** Set when a write covered fewer units than asked. See MAX_UNITS_PER_WRITE. */
        @AuraEnabled public String deferred;
        @AuraEnabled public List<OptionDTO> relationshipTypes = new List<OptionDTO>();
        @AuraEnabled public List<OptionDTO> relationshipSubTypes = new List<OptionDTO>();
    }

    /** A person the identity search found. */
    public class PersonDTO {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String nationality;
        @AuraEnabled public String residentStatus;
        /** True when this person is already the buyer or a joint owner here. */
        @AuraEnabled public Boolean alreadyOnThisBooking = false;
        /** Why they cannot be used, when they cannot. Null when they can. */
        @AuraEnabled public String blockedReason;
        /* 2.0 - MSC-180. True when the match is a company account. No longer a
           blocked state: the drawer shows a Company chip and the add goes ahead
           under the company rules. */
        @AuraEnabled public Boolean isCompany = false;

        /* 2.1: KYC, from MODON's joint owner check (see applyKyc). */
        /** True when MODON's check passes, so the add will be accepted. */
        @AuraEnabled public Boolean kycReady = false;
        /** MODON's message when it does not pass. It reports one problem at a time. */
        @AuraEnabled public String kycIssue;
        /** The KYC link: NOT_SENT | SENDING | SENT | EXPIRED | VERIFIED. */
        @AuraEnabled public String kycStatus;
        @AuraEnabled public Datetime kycSentOn;
        /** True when a KYC link can be sent to this person now. */
        @AuraEnabled public Boolean canSendKyc = false;
        /** Why a link cannot be sent. Null when it can. */
        @AuraEnabled public String kycBlockedReason;

        /* 2.2: set only when createPerson was stopped by existing customers. accountId is then
           null, nothing was written, and the rep chooses one of these. */
        @AuraEnabled public List<MatchDTO> matches;
        /** 2.2: ALLOW_NEW_CUSTOMER_DESPITE_MATCH, so the drawer offers "create anyway" only when it is on. */
        @AuraEnabled public Boolean createDespiteMatchAllowed = false;
    }

    /** 2.2: one existing customer the new person's details match, as the buyer's chooser shows it. */
    public class MatchDTO {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String mobile;
        @AuraEnabled public String nationality;
        @AuraEnabled public String residentStatus;
        /** eid | passport | email | mobile (SalesConsoleLeadController.matchedOnFor). */
        @AuraEnabled public String matchedOn;
        /** Why this one cannot be the joint owner (the buyer, or already on the booking). */
        @AuraEnabled public String blockedReason;
    }

    /** 2.2: carries the matches out of resolveOrCreatePerson. Never reaches the browser as such. */
    private class MatchesFoundException extends Exception {
        public List<Account> matches = new List<Account>();
    }

    public class OptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public OptionDTO(String v) {
            this.value = v;
            this.label = v;
        }
    }

    // ======================================================================
    // inputs
    // ======================================================================

    public class AddOwnerInput {
        @AuraEnabled public Id opportunityId { get; set; }
        /** The order the rep is looking at. Decides which unit the answer describes. */
        @AuraEnabled public Id salesOrderId { get; set; }
        /** Which units this person goes on. Null or empty means every open unit. */
        @AuraEnabled public List<Id> targetOrderIds { get; set; }
        /** An existing person. Null means create one from the fields below. */
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public Decimal share { get; set; }
        @AuraEnabled public String relationshipType { get; set; }
        @AuraEnabled public String relationshipSubType { get; set; }
        // ── the new person, when accountId is null ──
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobile { get; set; }
        @AuraEnabled public String nationality { get; set; }
        @AuraEnabled public String residentStatus { get; set; }
        @AuraEnabled public String eidNumber { get; set; }
        @AuraEnabled public String passportNumber { get; set; }
        // ── 2.0 - MSC-180. the new company, when accountId is null and the rep chose
        //    the company path. The flag only picks which CREATE runs; once an account
        //    exists, the RECORD decides which rules apply, never this. ──
        @AuraEnabled public Boolean isCompany { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String tradeLicence { get; set; }
        /* 2.2: the rep saw the existing customers and still wants a new person. Honoured only
           while ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on. */
        @AuraEnabled public Boolean createDespiteMatch { get; set; }
        // Required for the Lightning bridge to deserialise this from the LWC.
        public AddOwnerInput() {}
    }

    public class UpdateOwnerInput {
        @AuraEnabled public Id opportunityId { get; set; }
        @AuraEnabled public Id salesOrderId { get; set; }
        /** Which party. Always an existing joint owner's Account. */
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public Decimal share { get; set; }
        @AuraEnabled public String relationshipType { get; set; }
        @AuraEnabled public String relationshipSubType { get; set; }
        /**
         * The units this person should end on. May add units; may not drop one.
         * Dropping a unit is removing a joint owner, which is a Service Request.
         */
        @AuraEnabled public List<Id> targetOrderIds { get; set; }
        /*
         * 1.2 - CONTACT DETAIL, FOR BLANK FIELDS ONLY.
         *
         * Phase 1 asks for a last name, a Resident Status and one document, which is
         * the right bar for adding a co-owner to a contract. It is not enough to send
         * them anything: sendKYCForm wants nationality, residency, email and mobile,
         * and without a way to supply those later the console can show a person who
         * can never be verified from it. Anything set here is written ONLY where the
         * Account's own field is blank - see fillBlankContactDetails.
         */
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String mobile { get; set; }
        @AuraEnabled public String nationality { get; set; }
        @AuraEnabled public String residentStatus { get; set; }
        public UpdateOwnerInput() {}
    }

    // ======================================================================
    // 1 - the booking's owners
    // ======================================================================

    /**
     * Who is buying this booking, on which units, holding what.
     *
     * Never throws and never returns null: the panel renders a state, the same contract
     * getComplianceState and getChecklist already keep.
     */
    @AuraEnabled(cacheable=false)
    public static OwnersDTO getOwners(Id opportunityId, Id salesOrderId) {
        OwnersDTO dto = new OwnersDTO();
        try {
            Ctx c = resolve(opportunityId, salesOrderId);
            dto.blockedReason = c.blockedReason;
            dto.buyerIsCompany = c.buyerIsCompany; // 2.0 - carried even when blocked
            if (!c.ok) {
                return dto;
            }
            return describe(c, dto);
        } catch (Exception e) {
            dto.available = false;
            dto.blockedReason = friendly(e.getMessage());
            return dto;
        }
    }

    /**
     * 1.4 - HOW MANY PEOPLE ARE ON THIS BOOKING, for a host that has not opened the panel.
     *
     * MSC-084 puts the Ownership panel behind a tab on the My Bookings detail, beside
     * Payment plan and Documents, and those two carry a count because the data behind
     * them is already loaded. This one is not - so without this the third tab would be
     * the only one with no number, and the number is the thing that makes a rep open it.
     *
     * DELIBERATELY THE PANEL'S OWN ANSWER rather than a cheaper count of its own. A badge
     * reading 3 above a panel listing 2 is worse than no badge at all, and there are four
     * separate ways the two could have disagreed: a company-account buyer (the panel
     * refuses the whole booking, a naive count would still say 1), a booking whose every
     * unit is cancelled, a person recorded twice, and rows on units that are dead. Every
     * one of those is already decided inside getOwners, which never throws by contract -
     * so it is asked, and its answer is counted. One definition, and it is the one on
     * screen.
     *
     * Not @AuraEnabled: SalesConsoleBookingListController calls it, no LWC does.
     */
    public static Integer partyCount(Id opportunityId) {
        return partyStats(opportunityId).partyCount;
    }

    /**
     * 1.5 - the three numbers the booking detail's tabs are labelled with.
     *
     * MSC-088 splits Owners and Verification into two tabs, so the detail needs a
     * count for each of them before either is opened. All three come from ONE
     * getOwners - the same answer the panels themselves render - because a badge that
     * disagrees with the list beneath it is worse than no badge, and because a second
     * read would double the cost of a screen that only wanted to draw two numbers.
     *
     * Zero rather than a guess when there is nothing to count: My Bookings lists
     * cancelled and voided orders deliberately, and a company-account buyer is refused
     * by the panel outright.
     *
     * Not @AuraEnabled - Apex calls this, not a browser.
     */
    public class PartyStats {
        public Integer partyCount = 0;
        public Integer verifiedCount = 0;
        public Integer verifiableCount = 0;
    }

    public static PartyStats partyStats(Id opportunityId) {
        PartyStats stats = new PartyStats();
        OwnersDTO dto = getOwners(opportunityId, null);
        if (dto == null) {
            return stats;
        }
        if (dto.parties != null) {
            stats.partyCount = dto.parties.size();
        }
        if (dto.verifiedCount != null) {
            stats.verifiedCount = dto.verifiedCount;
        }
        if (dto.verifiableCount != null) {
            stats.verifiableCount = dto.verifiableCount;
        }
        return stats;
    }

    // ======================================================================
    // 2 - finding the person before creating them
    // ======================================================================

    /**
     * Search before create.
     *
     * A co-owner is very often already an Account - as the buyer of another unit, or as
     * someone else's joint owner - and 2,230 of the 2,236 joint owners in preprod point
     * at a Person Account. Creating a second record for a person the org already knows is
     * the mistake this exists to prevent, which is why the panel cannot reach the create
     * form without coming through here first.
     *
     * The match itself is SalesConsoleLeadController's, not a second copy. That method
     * carries the NO_MATCH fix from its 1.16 - a null bind matched every row where the
     * field was null, and nine consecutive console customers were converted into one
     * stranger's account before it was found. A second matcher would reintroduce it.
     */
    @AuraEnabled(cacheable=false)
    public static List<PersonDTO> findPerson(Id opportunityId, String idNumber) {
        List<PersonDTO> out = new List<PersonDTO>();
        if (String.isBlank(idNumber)) {
            return out;
        }
        String doc = idNumber.trim();

        /* Passed as BOTH documents so either field can match: a rep types the number in
           front of them, and which field it belongs in is the org's business, not
           theirs. */
        Id accountId = SalesConsoleLeadController.matchAccountByDocument(doc, doc, null);
        /* 2.0 - MSC-180. PERSON FIRST, COMPANY SECOND, and the order is the guarantee:
           no number that resolved to a person yesterday resolves differently today.
           Only where the person search finds nobody does the org matcher run - the
           purpose-built one, whose IsPersonAccount = FALSE and non-customer record
           type exclusions matchAccountByDocument cannot carry (its own 1.19 header
           says why). A broker agency or an ambassador account can therefore never
           come back from this search. */
        if (accountId == null) {
            accountId = SalesConsoleLeadController.matchOrganisationAccount(doc);
        }
        if (accountId == null) {
            return out;
        }

        // 2.1: one builder for the search, checkPerson, createPerson and the KYC link
        PersonDTO p = toPersonDTO(opportunityId, null, accountId);
        if (p != null) {
            out.add(p);
        }
        return out;
    }

    /**
     * 2.1: the person card the drawer shows, with their KYC state.
     * Null when the account cannot be read.
     */
    private static PersonDTO toPersonDTO(Id opportunityId, Id salesOrderId, Id accountId) {
        Account a = loadPerson(accountId);
        if (a == null) {
            return null;
        }

        PersonDTO p = new PersonDTO();
        p.accountId      = a.Id;
        p.name           = a.Name;
        p.email          = a.PersonEmail;
        p.mobile         = a.PersonMobilePhone;
        p.nationality    = a.Nationality__pc;
        p.residentStatus = a.UAE_Resident_Status__pc;

        /* 2.0 - MSC-180. A company match is a result now, not a refusal. The chip on
           the found card says what it is; merged and already-on-booking still block,
           for a company exactly as for a person. */
        p.isCompany = (a.IsPersonAccount != true);
        if (a.Is_Merged__c == true) {
            p.blockedReason = 'That account was merged into another. Search again using the surviving account.';
        } else if (opportunityId != null) {
            p.alreadyOnThisBooking = isAlreadyOnBooking(opportunityId, a.Id);
            if (p.alreadyOnThisBooking) {
                p.blockedReason = a.Name + ' is already on this booking.';
            }
        }
        if (p.blockedReason == null) {
            applyKyc(p, a, opportunityId, salesOrderId);
        }
        return p;
    }

    /**
     * 2.1: runs MODON's joint owner KYC check on a row that is never saved.
     *
     * It is the same check the insert meets (JointOwnerTriggerHelper.checkJointOwnerKYC),
     * so the drawer and the add cannot disagree, and the console keeps no copy of the rule.
     * MODON's check calls addError on the row; the errors are read back here.
     */
    private static void applyKyc(PersonDTO p, Account a, Id opportunityId, Id salesOrderId) {
        JointOwner__c probe = new JointOwner__c(
            JointOwnerAccount__c = a.Id,
            Opportunity__c       = opportunityId,
            SalesOrder__c        = salesOrderId
        );
        try {
            JointOwnerTriggerHelper.checkJointOwnerKYC(new List<SObject>{ probe }, null);
            p.kycReady = !probe.hasErrors();
            if (!p.kycReady) {
                p.kycIssue = probe.getErrors()[0].getMessage();
            }
        } catch (Exception e) {
            p.kycReady = false;
            p.kycIssue = friendly(e.getMessage());
        }

        // the KYC link, by the same rules as a joint owner's row (applyVerification)
        PartyDTO party = new PartyDTO();
        applyVerification(party, a);
        p.kycStatus        = party.verificationStatus;
        p.kycSentOn        = party.verificationSentOn;
        p.kycBlockedReason = party.verificationBlockedReason;
        p.canSendKyc       = party.canSendVerification == true
            && !SalesConsoleVerificationService.VERIFIED.equals(party.verificationStatus);
    }

    /** 2.1: asks MODON's check again, e.g. after the person finished their KYC. */
    @AuraEnabled
    public static PersonDTO checkPerson(Id opportunityId, Id salesOrderId, Id accountId) {
        if (accountId == null) {
            throw refuse('No person was selected.');
        }
        PersonDTO p = toPersonDTO(opportunityId, salesOrderId, accountId);
        if (p == null) {
            throw refuse('That person could no longer be found.');
        }
        return p;
    }

    /**
     * 2.1: sends a KYC link to a person who is not on the booking yet.
     *
     * sendVerification only serves people already on the booking, and MODON's check now
     * stops anyone being added before their KYC is done. The guards are the ones an add
     * would meet: a usable person, not the buyer, not already on the booking, and a unit
     * that can still take a joint owner.
     */
    @AuraEnabled
    public static PersonDTO sendCandidateVerification(Id opportunityId, Id salesOrderId, Id accountId) {
        if (accountId == null) {
            throw refuse('No person was selected.');
        }
        Ctx c = resolve(opportunityId, salesOrderId);
        if (!c.ok) {
            throw refuse(blocked(c));
        }
        Account a = loadPerson(accountId);
        checkPersonIsUsable(a);
        checkNotTheBuyer(c, a);
        if (isAlreadyOnBooking(opportunityId, accountId)) {
            throw refuse(a.Name + ' is already on this booking. Send the link from their row.');
        }
        List<SalesOrder__c> open = resolveTargets(c, null);

        PersonDTO p = toPersonDTO(opportunityId, salesOrderId, accountId);
        if (p == null || p.canSendKyc != true) {
            throw refuse(
                p != null && String.isNotBlank(p.kycBlockedReason)
                    ? p.kycBlockedReason
                    : 'A KYC link cannot be sent to ' + a.Name + ' yet.'
            );
        }

        // the unit the form names: the one on screen when it can take an owner, else the first open one
        Id unitId = open[0].Unit__c;
        for (SalesOrder__c so : open) {
            if (so.Id == c.focusedOrderId) {
                unitId = so.Unit__c;
            }
        }
        try {
            SalesConsoleVerificationService.stampUnitContextForParty(accountId, unitId);
            SalesConsoleVerificationService.enqueueSend(accountId);
        } catch (Exception e) {
            throw refuse(friendly(e.getMessage()));
        }

        // SENDING until MODON's flow stamps the send time, as for a joint owner's row
        p.kycStatus  = SalesConsoleVerificationService.SENDING;
        p.canSendKyc = false;
        return p;
    }

    /**
     * 2.1: creates a new person (or company) without adding them to the booking.
     *
     * A new person has no KYC, so MODON's check would refuse the add and roll the new
     * account back with it. Creating them first lets the rep send the KYC link; the add
     * follows once KYC is done. Same create and the same checks addOwner uses.
     */
    @AuraEnabled
    public static PersonDTO createPerson(AddOwnerInput input) {
        if (input == null) {
            throw refuse('No details were supplied.');
        }
        Ctx c = resolve(input.opportunityId, input.salesOrderId);
        if (!c.ok) {
            throw refuse(blocked(c));
        }
        // no one is created for a booking that cannot take a joint owner
        resolveTargets(c, null);

        Savepoint sp = Database.setSavepoint();
        try {
            Account person = input.accountId == null && input.isCompany == true
                ? resolveOrCreateCompany(c, input)
                : resolveOrCreatePerson(c, input);
            if (person != null && person.IsPersonAccount != true) {
                checkCompanyIsUsable(person);
            } else {
                checkPersonIsUsable(person);
            }
            checkNotTheBuyer(c, person);
            return toPersonDTO(input.opportunityId, input.salesOrderId, person.Id);

        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (MatchesFoundException e) {
            /* 2.2: nothing was written; the rep chooses one of them */
            Database.rollback(sp);
            return chooserFor(c, input, e.matches);
        } catch (DmlException e) {
            Database.rollback(sp);
            throw refuse(friendly(e.getDmlMessage(0)));
        } catch (Exception e) {
            Database.rollback(sp);
            throw refuse(friendly(e.getMessage()));
        }
    }

    /**
     * 2.2: the matches createPerson stopped on, as the drawer's chooser shows them. The buyer and
     * anyone already on the booking are listed but marked, so the rep sees why they cannot be used.
     */
    private static PersonDTO chooserFor(Ctx c, AddOwnerInput input, List<Account> matches) {
        PersonDTO p = new PersonDTO();
        p.name = ((String.isBlank(input.firstName) ? '' : input.firstName.trim() + ' ')
            + (String.isBlank(input.lastName) ? '' : input.lastName.trim())).trim();
        p.createDespiteMatchAllowed = AurelixNewCustomerSwitch.isOn();
        p.matches = new List<MatchDTO>();
        String eid   = trimmed(input.eidNumber);
        String pass  = trimmed(input.passportNumber);
        String email = trimmed(input.email);
        String phone = trimmed(input.mobile);
        for (Account a : matches) {
            MatchDTO m = new MatchDTO();
            m.accountId      = a.Id;
            m.name           = a.Name;
            m.email          = a.PersonEmail;
            m.mobile         = a.PersonMobilePhone;
            m.nationality    = a.Nationality__pc;
            m.residentStatus = a.UAE_Resident_Status__pc;
            m.matchedOn      = SalesConsoleLeadController.matchedOnFor(a, eid, pass, email, phone);
            if (a.IsPersonAccount != true) {
                m.blockedReason = a.Name + ' is a company account.';
            } else if (c.buyer != null && a.Id == c.buyer.Id) {
                m.blockedReason = a.Name + ' is the primary owner on this booking.';
            } else if (isAlreadyOnBooking(input.opportunityId, a.Id)) {
                m.blockedReason = a.Name + ' is already on this booking.';
            }
            p.matches.add(m);
        }
        return p;
    }

    /**
     * 2.2: may this person use the joint owner's manual KYC route from this booking? Null when
     * they may: a person who is already a joint owner here, or one who could be added now (the
     * guards an add meets before MODON's KYC check: a usable person, not the buyer, and a unit that
     * can still take a joint owner). Otherwise the sentence to show. Never throws.
     */
    public static String partyProblem(Id opportunityId, Id accountId) {
        if (opportunityId == null || accountId == null) {
            return 'No person was selected.';
        }
        try {
            Account a = loadPerson(accountId);
            if (a == null) {
                return 'That person could no longer be found.';
            }
            if (a.IsPersonAccount != true) {
                return 'Only a person has a manual KYC of their own here.';
            }
            List<Opportunity> opps = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            if (opps.isEmpty()) {
                return 'Booking not found.';
            }
            if (opps[0].AccountId == accountId) {
                return a.Name + ' is the primary owner on this booking.';
            }
            if (isAlreadyOnBooking(opportunityId, accountId)) {
                return null;
            }
            Ctx c = resolve(opportunityId, null);
            if (!c.ok) {
                return blocked(c);
            }
            checkPersonIsUsable(a);
            checkNotTheBuyer(c, a);
            resolveTargets(c, null);
            return null;
        } catch (Exception e) {
            return friendly(e.getMessage());
        }
    }

    // ======================================================================
    // 3 - adding a person
    // ======================================================================

    /**
     * Puts one person on one or more units of this booking.
     *
     * Every precondition is settled before a single row is written, and the Person
     * Account - when one has to be created - is created inside the same savepoint, so a
     * refusal on the third unit cannot leave a stranger's account behind.
     */
    @AuraEnabled
    public static OwnersDTO addOwner(AddOwnerInput input) {
        if (input == null) {
            throw refuse('No details were supplied.');
        }
        Ctx c = resolve(input.opportunityId, input.salesOrderId);
        if (!c.ok) {
            throw refuse(blocked(c));
        }

        Decimal share = input.share;
        String relType = trimmed(input.relationshipType);
        String relSub  = trimmed(input.relationshipSubType);
        checkShareRange(share);
        checkRelationship(relType, relSub);

        List<SalesOrder__c> targets = resolveTargets(c, input.targetOrderIds);
        String deferredNote = null;
        if (targets.size() > MAX_UNITS_PER_WRITE) {
            List<SalesOrder__c> kept = new List<SalesOrder__c>();
            List<String> left = new List<String>();
            for (Integer i = 0; i < targets.size(); i++) {
                if (i < MAX_UNITS_PER_WRITE) { kept.add(targets[i]); }
                else { left.add(unitNameOf(targets[i])); }
            }
            targets = kept;
            deferredNote = 'Added to the first ' + MAX_UNITS_PER_WRITE + ' units. Still to do: '
                + String.join(left, ', ') + '. Add them in a second pass.';
        }

        Savepoint sp = Database.setSavepoint();
        try {
            /* 2.0 - MSC-180. input.isCompany only picks which CREATE runs when there
               is no accountId. Once an account is in hand, the RECORD decides which
               rule set applies - so a crafted call cannot walk a company through the
               person gates or the other way round. */
            Account person = input.accountId == null && input.isCompany == true
                ? resolveOrCreateCompany(c, input)
                : resolveOrCreatePerson(c, input);
            if (person != null && person.IsPersonAccount != true) {
                checkCompanyIsUsable(person);
                checkCompanyRelationship(relType);
            } else {
                checkPersonIsUsable(person);
            }
            checkNotTheBuyer(c, person);

            Truth truth = new Guard().read(orderIds(targets));
            for (SalesOrder__c so : targets) {
                checkWritable(so);
                checkCapacity(so, truth, person, share);
            }

            List<JointOwner__c> written = new List<JointOwner__c>();
            for (SalesOrder__c so : targets) {
                JointOwner__c row = buildRow(so.Id, person.Id, share, relType, relSub);
                // One row per DML. See writeRow's header for why this is not a bulk insert.
                insert row;
                written.add(row);
            }

            OwnersDTO out = describe(resolve(input.opportunityId, input.salesOrderId), new OwnersDTO());
            out.warning  = staleSpaWarning(targets);
            out.deferred = deferredNote;
            return out;

        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (DmlException e) {
            Database.rollback(sp);
            throw refuse(friendly(e.getDmlMessage(0)));
        } catch (Exception e) {
            Database.rollback(sp);
            throw refuse(friendly(e.getMessage()));
        }
    }

    // ======================================================================
    // 4 - changing a person's part in the booking
    // ======================================================================

    /**
     * Changes a joint owner's share or relationship, and may put them on a further unit.
     *
     * IT CANNOT TAKE THEM OFF ONE. Narrowing the unit set is removing a joint owner from
     * a unit, and removal is a Service Request by the client's decision - MODON's
     * afterDeleteMethod is empty, so a delete leaves JO1__c..JO6__c pointing at the
     * removed person and every reader of the flattened fields keeps seeing them. The
     * request is refused with the route rather than half-honoured.
     */
    @AuraEnabled
    public static OwnersDTO updateOwner(UpdateOwnerInput input) {
        if (input == null) {
            throw refuse('No details were supplied.');
        }
        Ctx c = resolve(input.opportunityId, input.salesOrderId);
        if (!c.ok) {
            throw refuse(blocked(c));
        }
        if (input.accountId == null) {
            throw refuse('No joint owner was selected.');
        }

        Decimal share = input.share;
        String relType = trimmed(input.relationshipType);
        String relSub  = trimmed(input.relationshipSubType);
        checkShareRange(share);
        checkRelationship(relType, relSub);

        Map<Id, JointOwner__c> existing = new Map<Id, JointOwner__c>();
        for (JointOwner__c jo : c.jointOwners) {
            if (jo.JointOwnerAccount__c == input.accountId) {
                existing.put(jo.SalesOrder__c, jo);
            }
        }
        if (existing.isEmpty()) {
            throw refuse('That person is not a joint owner on this booking.');
        }

        /* An empty unit list here means "the units they are already on", NOT "every open
           unit" the way it does on addOwner. The two defaults have to differ: on an add,
           silence means the whole basket, which is the common case and should cost no
           decision; on an edit, silence means "just change the share", because expanding
           someone onto units nobody asked about would be a write the caller never
           requested and could not see coming. */
        List<SalesOrder__c> targets;
        if (input.targetOrderIds == null || input.targetOrderIds.isEmpty()) {
            targets = new List<SalesOrder__c>();
            for (Id soId : existing.keySet()) {
                if (c.orders.containsKey(soId)) { targets.add(c.orders.get(soId)); }
            }
        } else {
            targets = resolveTargets(c, input.targetOrderIds);
        }
        Set<Id> targetIds = orderIds(targets);

        // A unit they are on today and would not be on afterwards is a removal.
        List<String> dropped = new List<String>();
        for (Id soId : existing.keySet()) {
            if (!targetIds.contains(soId)) {
                dropped.add(unitNameOf(c.orders.get(soId)));
            }
        }
        if (!dropped.isEmpty()) {
            throw refuse(
                'Removing a joint owner from ' + String.join(dropped, ', ') + ' is not done in '
                + 'the console. Raise a Joint Owner Deletion service request.'
            );
        }

        List<SalesOrder__c> newUnits = new List<SalesOrder__c>();
        for (SalesOrder__c so : targets) {
            if (!existing.containsKey(so.Id)) { newUnits.add(so); }
        }
        if (newUnits.size() > MAX_UNITS_PER_WRITE) {
            throw refuse(
                'That is more than ' + MAX_UNITS_PER_WRITE + ' new units at once. Add them in smaller batches.'
            );
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Account person = loadPerson(input.accountId);
            /* 1.6 - MSC-091. THE GATE, AND IT IS HERE.

               The row withholds Edit once a link has gone out, but a withheld button
               is a hint and this is the rule: an @AuraEnabled method is a public
               endpoint, and a stale tab open from before the link was sent still
               carries a live Edit. Checked BEFORE fillBlankContactDetails, so a
               refusal cannot leave contact details written against a person whose
               ownership was then refused - and before every capacity and share check
               below, so the sentence the rep gets is about the nearest obstacle.

               It asks statusForParty, which is what the panel asked, so the button
               and the gate cannot come to different answers about the same person. */
            checkNotAlreadySent(person);
            /* 1.2 - BEFORE checkPersonIsUsable, and that ordering is the whole trick.
               That check refuses a blank UAE_Resident_Status__pc, so a fill placed
               after it could never run for the very records that need it - which, in
               DEV_1, is 94.8% of them. Inside the savepoint, so a refusal further down
               takes the contact details back out with everything else. */
            person = fillBlankContactDetails(person, input);
            /* 2.0 - MSC-180. The record decides, as on addOwner. fillBlank above is
               already a no-op for a company (its own guard), so a company edit is
               share, relationship and units - nothing else. */
            if (person != null && person.IsPersonAccount != true) {
                checkCompanyIsUsable(person);
                checkCompanyRelationship(relType);
            } else {
                checkPersonIsUsable(person);
            }

            Truth truth = new Guard().read(targetIds);
            for (SalesOrder__c so : targets) {
                checkWritable(so);
                if (!existing.containsKey(so.Id)) {
                    checkCapacity(so, truth, person, share);
                } else {
                    // The row already exists; only its share is moving.
                    checkShareChange(so, truth, existing.get(so.Id), share);
                }
            }

            for (JointOwner__c jo : existing.values()) {
                jo.OwnershipPercentage__c = share;
                jo.RelationshipType__c    = relType;
                jo.RelationshipSubType__c = relSub;
                update jo;
            }
            for (SalesOrder__c so : newUnits) {
                insert buildRow(so.Id, person.Id, share, relType, relSub);
            }

            OwnersDTO out = describe(resolve(input.opportunityId, input.salesOrderId), new OwnersDTO());
            out.warning = staleSpaWarning(targets);
            return out;

        } catch (AuraHandledException e) {
            Database.rollback(sp);
            throw e;
        } catch (DmlException e) {
            Database.rollback(sp);
            throw refuse(friendly(e.getDmlMessage(0)));
        } catch (Exception e) {
            Database.rollback(sp);
            throw refuse(friendly(e.getMessage()));
        }
    }

    // ======================================================================
    // 5 - sending one person their identity verification link
    // ======================================================================

    /**
     * 1.2 - PUTS ONE PARTY OF THIS BOOKING INTO MODON'S SIGNZY PIPELINE.
     *
     * There is almost nothing new underneath this. enqueueSend, SendKycLinkJob and
     * MODON's own sendKYCForm have taken an Account Id since MSC-054; what was missing
     * was a way in for somebody who is not the Opportunity's own customer, and the
     * decision about WHICH unit their form should name.
     *
     * THE GUARD THAT MATTERS. accountId must already be a party on this booking. It is
     * the only genuinely new surface this method opens - without it, any Account Id
     * posted from a browser would start a real identity journey, send a real person a
     * real email and stamp their record. Membership is taken from the picture the panel
     * itself renders, so what can be sent to is exactly what is on screen.
     *
     * IT IS NOT GATED BY readOnly, AND THAT IS DELIBERATE. The SPA cut-off closes
     * ADDING an owner, because the contract has gone out with a fixed set of names on
     * it. Verifying the people already on it is a different question, and one that
     * usually arrives afterwards - refusing it would mean a joint owner added on Monday
     * could never be verified from the console on Wednesday. A dead booking is still
     * refused, by resolve.
     *
     * TWO HALVES, TWO TRANSACTIONS. The unit is stamped here and committed; the callout
     * is enqueued to run after. Both halves of that are forced, and the reasons are
     * written out in SendKycLinkJob's header - sendKYCForm calls out and then commits,
     * and MODON's email Flow fires on its update, so a stamp written afterwards would
     * reach the customer's form too late to appear in it.
     */
    @AuraEnabled
    public static OwnersDTO sendVerification(Id opportunityId, Id salesOrderId, Id accountId) {
        if (accountId == null) {
            throw refuse('No person was selected.');
        }
        Ctx c = resolve(opportunityId, salesOrderId);
        if (!c.ok) {
            throw refuse(blocked(c));
        }

        /* The picture, built once. It carries the membership test, every party's
           sendability and the reason where there is one, so this method never decides
           anything the panel was not already showing. */
        OwnersDTO dto = describe(c, new OwnersDTO());

        PartyDTO party = null;
        for (PartyDTO p : dto.parties) {
            if (p.accountId == accountId) {
                party = p;
                break;
            }
        }
        if (party == null) {
            throw refuse(
                'That person is not on this booking, so a verification link cannot be sent to them.'
            );
        }
        if (party.canSendVerification != true) {
            throw refuse(
                String.isBlank(party.verificationBlockedReason)
                    ? 'A verification link cannot be sent to ' + party.name + ' yet.'
                    : party.verificationBlockedReason
            );
        }

        try {
            SalesConsoleVerificationService.stampUnitContextForParty(
                accountId, unitForParty(c, party));
            SalesConsoleVerificationService.enqueueSend(accountId);
        } catch (Exception e) {
            throw refuse(friendly(e.getMessage()));
        }

        /* SENDING, not SENT. The link does not exist until the queueable has run and
           MODON's Flow has stamped KYC_Send_Date_Time__c; the console polls from here
           and says "Sending" rather than claiming something it cannot yet see. Exactly
           what SalesConsoleController.sendCustomerVerification does for the buyer. */
        party.verificationStatus = SalesConsoleVerificationService.SENDING;
        return dto;
    }

    /**
     * WHICH UNIT THIS PERSON'S VERIFICATION FORM SHOULD NAME.
     *
     * A basket gets ONE unit, for the reason stampUnitContext records: KYCUnitName__pc
     * is a single Text(255) and MODON's own getLatestUnitInfo is LIMIT 1, so one unit is
     * what the rest of the org shows a multi-unit customer.
     *
     * The unit the rep is looking at wins where this person is actually on it - that is
     * the one on screen when they pressed Send. Otherwise their own first holding, which
     * is a unit they are genuinely co-buying rather than one they are not. The primary
     * owner has no holdings here at all, so they fall through to the focused order,
     * which is the same unit the verification chain below would have sent.
     */
    private static Id unitForParty(Ctx c, PartyDTO party) {
        if (party != null && c.focusedOrderId != null) {
            for (HoldingDTO h : party.holdings) {
                if (h.salesOrderId == c.focusedOrderId) {
                    return unitIdOf(c, c.focusedOrderId);
                }
            }
        }
        if (party != null && !party.holdings.isEmpty()) {
            return unitIdOf(c, party.holdings[0].salesOrderId);
        }
        if (c.focusedOrderId != null) {
            return unitIdOf(c, c.focusedOrderId);
        }
        return c.orderList.isEmpty() ? null : c.orderList[0].Unit__c;
    }

    private static Id unitIdOf(Ctx c, Id orderId) {
        SalesOrder__c so = c.orders.get(orderId);
        return so == null ? null : so.Unit__c;
    }

    // ======================================================================
    // resolution
    // ======================================================================

    /** Everything one call needs, settled once so no two methods can disagree. */
    private class Ctx {
        Opportunity opp;
        Account buyer;
        Id buyerContactId;
        Id focusedOrderId;
        /** The live orders of this booking, by Id. */
        Map<Id, SalesOrder__c> orders = new Map<Id, SalesOrder__c>();
        /** The same, in unit order, for anything the rep reads. */
        List<SalesOrder__c> orderList = new List<SalesOrder__c>();
        /** Under sharing - what this rep is entitled to see. Never used by a guard. */
        List<JointOwner__c> jointOwners = new List<JointOwner__c>();
        String blockedReason;
        Boolean ok = false;
        /* 2.0 - MSC-180. The buyer is a company account. Owners stay manageable;
           only the person-shaped defaults (record type, residency copy) branch. */
        Boolean buyerIsCompany = false;
    }

    /**
     * One place where every precondition is settled.
     *
     * The Sales Orders are read whole and filtered in Apex rather than with a SOQL
     * NOT IN. It costs nothing at this row count and it means one definition of "dead"
     * - the case-insensitive one - decides both the query and every later check, so the
     * two cannot drift the way a SOQL filter and an Apex Set already have elsewhere.
     */
    private static Ctx resolve(Id opportunityId, Id salesOrderId) {
        Ctx c = new Ctx();

        if (opportunityId == null) {
            c.blockedReason = 'No booking selected.';
            return c;
        }

        List<Opportunity> opps = [
            SELECT Id, AccountId, PrimaryContact__c,
                   Account.Id, Account.Name, Account.IsPersonAccount, Account.RecordTypeId,
                   Account.PersonContactId, Account.PersonEmail, Account.PersonMobilePhone,
                   Account.Nationality__pc, Account.UAE_Resident_Status__pc,
                   Account.KYC_Completed_Date__c, Account.PassfortApprovalStatus__pc,
                   /* 1.3 - the other two ways of knowing somebody has already been sent
                      to compliance. SalesConsoleComplianceService.isAlreadySubmitted has
                      always read all three, because any one can be true alone: a profile
                      exists minutes before an approval status does. */
                   Account.profileId__pc, Account.profileId__c,
                   /* 1.2 - what statusForParty reads. The same four fields the
                      verification chain already uses for this same person, so the panel
                      above it and the chain below it cannot report different states. */
                   Account.KYC_Send_Date_Time__c, Account.KYC_Link_Status__c,
                   Account.Manual_KYC_Approval__c,
                   Account.Is_KYC_Link_Active__c, Account.KYC_Link_Expiry_At__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty() || opps[0].Account == null) {
            c.blockedReason = 'This booking has no primary owner yet.';
            return c;
        }
        c.opp   = opps[0];
        c.buyer = opps[0].Account;

        /* 2.0 - MSC-180. A corporate buyer no longer closes the panel. 1.8's sentence
           - a company is proved by the signed KYC & Wealth Form and Passfort, not by a
           link - is still every word true, and it still governs VERIFICATION: the
           primary party's chip says it (applyVerification's company branch) and the
           company's two tracks render beside the owners (dto.buyerIsCompany tells the
           pane to keep loading them). What it no longer does is forbid OWNERSHIP:
           joint owners on a corporate booking are managed here now, under exactly the
           per-party gates an individual booking runs. */
        c.buyerIsCompany = (c.buyer.IsPersonAccount != true);
        c.buyerContactId = c.buyer.PersonContactId != null
            ? c.buyer.PersonContactId
            : c.opp.PrimaryContact__c;

        Integer deadCount = 0;
        Set<String> deadStatuses = new Set<String>();
        for (SalesOrder__c so : [
            SELECT Id, Name, Status__c, SPAStatus__c, SPA_Send_Date_for_Signature__c,
                   Source_Entity__c, Opportunity__c, CustomerAccount__c,
                   Unit__c, Unit__r.Name
            FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY Name
        ]) {
            if (isDead(so)) {
                /* 1.4 - remembered, not merely skipped. See below. */
                deadCount++;
                if (String.isNotBlank(so.Status__c)) {
                    deadStatuses.add(so.Status__c);
                }
                continue;
            }
            c.orders.put(so.Id, so);
            c.orderList.add(so);
        }
        if (c.orders.isEmpty()) {
            /* 1.4 - A BOOKING WITH NO UNIT AND A BOOKING WHOSE UNITS ARE ALL CANCELLED
               ARE NOT THE SAME THING, and until MSC-084 they were told the same sentence.
               The journey never meets the second - it only ever renders this panel on a
               booking it is in the middle of making - but My Bookings lists cancelled and
               voided orders on purpose, and seven of the fourteen orders in DEV_1 that
               carry a joint owner are in exactly that state. A rep looking at a Voided
               order and reading "no confirmed unit yet" is being told something false
               about a record in front of them.

               The status is quoted rather than paraphrased, which is the same thing G3's
               refusal does: the ladder is Modon's and the words on it are theirs to
               change. Where the units disagree with each other there is no one value to
               quote, so the sentence says what is true of all of them. */
            if (deadCount == 0) {
                c.blockedReason = 'This booking has no confirmed unit yet.';
            } else if (deadStatuses.size() == 1) {
                c.blockedReason = 'This booking is at "' + new List<String>(deadStatuses)[0]
                    + '", so its owners can no longer be changed here.';
            } else {
                c.blockedReason = 'Every unit of this booking has been cancelled, '
                    + 'so its owners can no longer be changed here.';
            }
            return c;
        }

        /* The order the rep is looking at, but only if it is one this booking can show.
           Anything else - another booking's order, a cancelled one typed into a URL - is
           ignored rather than thrown, and the answer comes back describing the whole
           booking. The caller reads focusedSalesOrderId, never its own request. */
        if (salesOrderId != null && c.orders.containsKey(salesOrderId)) {
            c.focusedOrderId = salesOrderId;
        }

        c.jointOwners = [
            SELECT Id, JointOwnerAccount__c, SalesOrder__c, OwnershipPercentage__c,
                   RelationshipType__c, RelationshipSubType__c, CreatedDate, OwnerId,
                   JointOwnerAccount__r.Name, JointOwnerAccount__r.PersonContactId,
                   JointOwnerAccount__r.PersonEmail, JointOwnerAccount__r.PersonMobilePhone,
                   JointOwnerAccount__r.Nationality__pc,
                   JointOwnerAccount__r.UAE_Resident_Status__pc,
                   JointOwnerAccount__r.KYC_Completed_Date__c,
                   JointOwnerAccount__r.PassfortApprovalStatus__pc,
                   JointOwnerAccount__r.profileId__pc, JointOwnerAccount__r.profileId__c,
                   /* 1.2 - the same verification fields as the buyer's above, plus the
                      one that decides whether they can be verified here at all.
                      IsPersonAccount is not a formality: 127 of the 135 joint owner
                      accounts in DEV_1 are company accounts, and sendKYCForm refuses
                      those outright. */
                   JointOwnerAccount__r.IsPersonAccount,
                   JointOwnerAccount__r.KYC_Send_Date_Time__c,
                   JointOwnerAccount__r.KYC_Link_Status__c,
                   JointOwnerAccount__r.Manual_KYC_Approval__c,
                   JointOwnerAccount__r.Is_KYC_Link_Active__c,
                   JointOwnerAccount__r.KYC_Link_Expiry_At__c
            FROM JointOwner__c
            WHERE SalesOrder__c IN :c.orders.keySet()
            ORDER BY OwnershipPercentage__c DESC, CreatedDate
        ];

        c.ok = true;
        return c;
    }

    /** The blocked reason, or a safe default. Never let a refusal be wordless. */
    private static String blocked(Ctx c) {
        return String.isBlank(c.blockedReason)
            ? 'Joint owners cannot be changed on this booking.'
            : c.blockedReason;
    }

    // ======================================================================
    // the picture the panel renders
    // ======================================================================

    private static OwnersDTO describe(Ctx c, OwnersDTO dto) {
        if (!c.ok) {
            dto.blockedReason = c.blockedReason;
            dto.buyerIsCompany = c.buyerIsCompany; // 2.0 - true even when blocked
            return dto;
        }
        dto.available          = true;
        dto.opportunityId      = c.opp.Id;
        dto.focusedSalesOrderId = c.focusedOrderId;
        dto.buyerIsCompany     = c.buyerIsCompany; // 2.0 - MSC-180
        dto.isMultiUnit        = c.orderList.size() > 1;
        dto.relationshipTypes    = options('RelationshipType__c');
        dto.relationshipSubTypes = options('RelationshipSubType__c');

        Truth truth = new Guard().read(c.orders.keySet());

        // ── the units ───────────────────────────────────────────────────────
        Map<Id, Integer> visibleByOrder = new Map<Id, Integer>();
        for (JointOwner__c jo : c.jointOwners) {
            Integer n = visibleByOrder.containsKey(jo.SalesOrder__c) ? visibleByOrder.get(jo.SalesOrder__c) : 0;
            visibleByOrder.put(jo.SalesOrder__c, n + 1);
        }

        Boolean anyOpen = false;
        List<String> empties = new List<String>();
        for (SalesOrder__c so : c.orderList) {
            UnitDTO u = new UnitDTO();
            u.salesOrderId  = so.Id;
            u.bookingRef    = so.Name;
            u.unitId        = so.Unit__c;
            u.unitName      = unitNameOf(so);
            u.status        = so.Status__c;
            u.ownerCount    = truth.countFor(so.Id);
            u.allocatedShare = truth.shareFor(so.Id);
            u.slotsRemaining = Math.max(0, MAX_OWNERS - u.ownerCount);

            Integer visible = visibleByOrder.containsKey(so.Id) ? visibleByOrder.get(so.Id) : 0;
            u.hiddenOwnerCount = Math.max(0, u.ownerCount - visible);

            if (inSet(new Set<String>{ EGYPT }, so.Source_Entity__c)) {
                u.open = false;
                u.closedReason = 'Modon Egypt bookings use their own Add Joint Owners screen.';
            } else {
                String why = spaClosedReason(so);
                u.open = (why == null);
                u.closedReason = why;
                if (u.open && inSet(new Set<String>{ SPA_WARN }, so.SPAStatus__c)) {
                    u.warning = 'The SPA for ' + u.unitName + ' has already been generated. '
                        + 'It must be regenerated before it is sent to the customer.';
                }
            }
            if (u.open) { anyOpen = true; }
            if (u.ownerCount == 0) { empties.add(u.unitName); }
            dto.units.add(u);
        }
        dto.readOnly = !anyOpen;
        if (dto.readOnly) {
            dto.blockedReason = c.orderList.size() == 1
                ? dto.units[0].closedReason
                : 'Every unit on this booking is past the point where a joint owner can be added.';
        }
        dto.unitsWithNoJointOwner = empties;

        // ── the parties, buyer first ────────────────────────────────────────
        PartyDTO primary = new PartyDTO();
        primary.accountId       = c.buyer.Id;
        primary.personContactId = c.buyerContactId;
        primary.name            = c.buyer.Name;
        primary.isPrimary       = true;
        primary.residentStatus  = c.buyer.UAE_Resident_Status__pc;
        primary.nationality     = c.buyer.Nationality__pc;
        primary.email           = c.buyer.PersonEmail;
        primary.mobile          = c.buyer.PersonMobilePhone;
        primary.kycCompletedDate = c.buyer.KYC_Completed_Date__c;
        primary.isCompany       = c.buyerIsCompany; // 2.0 - MSC-180
        applyVerification(primary, c.buyer);
        dto.parties.add(primary);

        /* Each party's own Account, kept for the compliance pass below. It runs second
           because it needs one query across EVERY party's contact - see applyCompliance -
           and a query per person on a six-owner basket is six queries for one chip. */
        Map<Id, Account> accountOf = new Map<Id, Account>();
        if (c.buyer.Id != null) {
            accountOf.put(c.buyer.Id, c.buyer);
        }

        Map<Id, PartyDTO> byAccount = new Map<Id, PartyDTO>();
        for (JointOwner__c jo : c.jointOwners) {
            if (jo.JointOwnerAccount__c == null) {
                continue;
            }
            PartyDTO p = byAccount.get(jo.JointOwnerAccount__c);
            if (p == null) {
                Account a = jo.JointOwnerAccount__r;
                p = new PartyDTO();
                p.accountId       = jo.JointOwnerAccount__c;
                p.personContactId = a == null ? null : a.PersonContactId;
                p.name            = a == null ? null : a.Name;
                p.residentStatus  = a == null ? null : a.UAE_Resident_Status__pc;
                p.nationality     = a == null ? null : a.Nationality__pc;
                p.email           = a == null ? null : a.PersonEmail;
                p.mobile          = a == null ? null : a.PersonMobilePhone;
                p.kycCompletedDate = a == null ? null : a.KYC_Completed_Date__c;
                p.isCompany        = a != null && a.IsPersonAccount != true; // 2.0
                if (a != null) {
                    accountOf.put(jo.JointOwnerAccount__c, a);
                }
                p.relationshipType    = jo.RelationshipType__c;
                p.relationshipSubType = jo.RelationshipSubType__c;
                applyVerification(p, a);
                byAccount.put(jo.JointOwnerAccount__c, p);
                dto.parties.add(p);
            }
            HoldingDTO h = new HoldingDTO();
            h.jointOwnerId = jo.Id;
            h.salesOrderId = jo.SalesOrder__c;
            h.unitName     = unitNameOf(c.orders.get(jo.SalesOrder__c));
            h.share        = jo.OwnershipPercentage__c;
            h.addedOn      = jo.CreatedDate;
            /* Whether THIS rep can change the row. JointOwner__c is Private and
               SalesTeamSharing grants Read, not Edit, so a booking that changed hands
               carries rows its new owner can see and cannot touch. Saying so on the row
               beats a save that fails at the moment the rep presses it. */
            h.editable     = (jo.OwnerId == UserInfo.getUserId());
            p.holdings.add(h);
            p.unitNames.add(h.unitName);
            if (c.focusedOrderId == null || jo.SalesOrder__c == c.focusedOrderId) {
                p.share = jo.OwnershipPercentage__c;
            }
        }

        /* 1.3 - one query for the whole panel, before the pass that reads it. */
        Set<Id> partyContactIds = new Set<Id>();
        for (PartyDTO p : dto.parties) {
            if (p.personContactId != null) {
                partyContactIds.add(p.personContactId);
            }
        }
        Set<Id> inFlight = contactsAlreadyWithCompliance(partyContactIds);

        Set<Id> counted = new Set<Id>();
        for (PartyDTO p : dto.parties) {
            /* 1.4 - WHICH UNITS, NOT HOW MANY ROWS.
               holdings is the ledger and keeps every row, because a row is a record and
               hiding one would make the panel disagree with the related list. unitNames
               is a SENTENCE about that ledger, and a sentence must not repeat itself:
               SO-15095 in DEV_1 carries 64 JointOwner__c rows for one person on one unit
               - data that predates phase 1's guard and that MODON's own trigger would
               refuse today - and the row would otherwise have read "On WY-01" sixty-six
               times over. onAllUnits had the same fault in a form that changes an answer
               rather than a wording: two duplicate rows on a two-unit basket read as
               "on all 2 units" about somebody who is on one. Both now count DISTINCT
               SALES ORDERS, which is what both were always claiming to say. */
            Set<Id> ordersHeld = new Set<Id>();
            List<String> distinctUnits = new List<String>();
            for (HoldingDTO h : p.holdings) {
                if (ordersHeld.add(h.salesOrderId)) {
                    distinctUnits.add(h.unitName);
                }
            }
            p.unitNames = distinctUnits;
            if (!p.isPrimary) {
                p.onAllUnits = (ordersHeld.size() == c.orderList.size());
            }
            applyCompliance(p, accountOf.get(p.accountId), inFlight);
            /* 1.2 - the tally the head chip reads.
               COUNTED BY ACCOUNT, not by row. DEV_1 holds a booking whose buyer is
               also recorded as their own joint owner - data that predates the guard
               and that phase 1 refuses to create today - and that person appears
               twice in this list. They are one person, so "0 of 2 verified" would be
               a fraction about nobody. The rows still show what the records say. */
            /* 1.6 - MSC-091. Can this row still be changed, and if not, why not. The
               tests run in the order a rep meets them, so the sentence they get is
               about the nearest obstacle and not the furthest. */
            Boolean rowsAreMine = !p.holdings.isEmpty();
            for (HoldingDTO h : p.holdings) {
                if (h.editable != true) {
                    rowsAreMine = false;
                }
            }
            Boolean linkIsOut =
                p.verificationStatus != null
                && !SalesConsoleVerificationService.NOT_SENT.equals(p.verificationStatus);
            if (p.isPrimary == true) {
                p.canEdit = false;
            } else if (dto.readOnly == true) {
                p.canEdit = false;
                p.editBlockedReason = dto.blockedReason;
            } else if (!rowsAreMine) {
                p.canEdit = false;
                p.editBlockedReason = EDIT_NOT_YOURS;
            } else if (linkIsOut) {
                p.canEdit = false;
                p.editBlockedReason = editSentReason(p.name);
            } else {
                p.canEdit = true;
            }

            if (p.canEverVerify == true && p.accountId != null && counted.add(p.accountId)) {
                dto.verifiableCount++;
                if (SalesConsoleVerificationService.VERIFIED.equals(p.verificationStatus)) {
                    dto.verifiedCount++;
                }
                if (p.complianceSubmitted == true) {
                    dto.complianceSubmittedCount++;
                }
            }
        }

        dto.jointOwnerCount = byAccount.size();

        // ── the numbers the add form needs ──────────────────────────────────
        Id basis = c.focusedOrderId != null ? c.focusedOrderId : c.orderList[0].Id;
        dto.primaryShare    = 100 - truth.shareFor(basis);
        dto.slotsRemaining  = Math.max(0, MAX_OWNERS - truth.countFor(basis));

        dto.coverageLine = coverage(dto, c);
        return dto;
    }

    /**
     * 1.2 - ONE PERSON'S IDENTITY VERIFICATION, READ OFF THEIR OWN ACCOUNT.
     *
     * Applied identically to the primary owner and to every joint owner, because the
     * pipeline treats them identically: sendKYCForm takes an Account Id, writes back to
     * that Account, and knows nothing about who is buying what. A rule written twice
     * would be a rule that eventually says two different things about one person on one
     * screen.
     *
     * THREE ANSWERS, IN THIS ORDER, AND THE ORDER IS THE POINT.
     *
     *   canEverVerify   false for a company account. sendKYCForm refuses anything on
     *                   the Organization Account record type outright and walks Powers
     *                   of Attorney instead, which is not a joint owner's route. 127 of
     *                   the 135 joint owner accounts in DEV_1 are company accounts, so
     *                   this is the COMMON case here, not an edge - and the honest
     *                   answer is a sentence, never a button that would do nothing.
     *   detailsMissing  true when the only thing in the way is contact detail the
     *                   drawer can collect. This is what turns the row's action from
     *                   "Send link" into "Add details" rather than leaving the rep with
     *                   a reason and no way to act on it.
     *   canSend         everything else already passed.
     *
     * A person with no PersonContactId cannot be sent anything either - sendKYCForm's
     * own getLatestUnitInfo takes one and MODON's KYC_Response__c is keyed to it - and
     * that is not something a rep can fix from here, so it is reported and not offered.
     */
    /**
     * 1.3 - ONE PERSON'S COMPLIANCE, READ OFF THEIR OWN ACCOUNT.
     *
     * THREE INDEPENDENT WAYS OF KNOWING SOMEBODY HAS ALREADY BEEN SENT, because any one
     * of them can be true while the other two are not: Passfort has answered
     * (PassfortApprovalStatus__pc), a profile exists (profileId__pc / profileId__c), or a
     * transaction is in flight and nothing has come back yet. The last is the one 1.2
     * missed, and it is the one that is true for the several minutes between the rep
     * pressing Submit and Passfort replying - so a row that read only the approval status
     * said "not sent" about somebody who had just been sent, and invited the rep to send
     * them again. The definition is deliberately the same as
     * SalesConsoleComplianceService.isAlreadySubmitted's; that class refuses the second
     * submission whatever this says, and the two must not disagree on screen.
     *
     * canCheckCompliance MIRRORS THAT CLASS'S GATES, in its order - person account, a
     * contact, identity verification finished, residency known - so the row never offers
     * a check the server would refuse the moment it was pressed. The reason names the
     * NEAREST one only: a list of four is what the panel would have to become, and the
     * rep can only act on the first anyway.
     */
    private static void applyCompliance(PartyDTO p, Account a, Set<Id> inFlight) {
        if (p == null || a == null) {
            /* Same silence as applyVerification: under sharing this rep cannot read the
               account, and a claim about a record we could not see is not one to make. */
            return;
        }

        p.complianceStatus = a.PassfortApprovalStatus__pc;
        p.complianceSubmitted =
               String.isNotBlank(a.PassfortApprovalStatus__pc)
            || String.isNotBlank(a.profileId__pc)
            || String.isNotBlank(a.profileId__c)
            || (a.PersonContactId != null && inFlight.contains(a.PersonContactId));

        if (a.IsPersonAccount != true) {
            p.complianceBlockedReason =
                a.Name + ' is a company account. Compliance for a company is handled by '
                + 'Sales Operations from the account record.';
            return;
        }
        if (a.PersonContactId == null) {
            p.complianceBlockedReason =
                a.Name + ' has no contact record yet, so compliance cannot be checked '
                + 'here. Sales Operations can put that right.';
            return;
        }
        /* 18 Sep 2026: a manual KYC approval counts as finished (no completion date) */
        if (a.KYC_Completed_Date__c == null && !SalesConsoleVerificationService.isManuallyApproved(a)) {
            p.complianceBlockedReason =
                a.Name + ' has not finished identity verification yet. Compliance can be '
                + 'sent once they do.';
            return;
        }
        if (String.isBlank(a.UAE_Resident_Status__pc)) {
            p.complianceBlockedReason =
                'Set ' + a.Name + '\'s UAE resident status first - it decides what '
                + 'compliance needs.';
            return;
        }
        p.canCheckCompliance = true;
    }

    /**
     * Which of these people already have a compliance transaction open.
     *
     * ONE QUERY FOR THE WHOLE PANEL. A six-owner basket asked person by person would be
     * six queries for six chips, and this method is called on every read of the panel.
     * EntityType__c 'Individual' matches what the console's own submission creates and
     * what SalesConsoleComplianceService counts - a 'Notes' row is Passfort talking back
     * about somebody, not a submission of them.
     */
    private static Set<Id> contactsAlreadyWithCompliance(Set<Id> contactIds) {
        Set<Id> out = new Set<Id>();
        if (contactIds == null || contactIds.isEmpty()) {
            return out;
        }
        try {
            for (PassfortTransaction__c t : [
                SELECT Contact__c
                FROM PassfortTransaction__c
                WHERE Contact__c IN :contactIds
                AND EntityType__c = 'Individual'
            ]) {
                out.add(t.Contact__c);
            }
        } catch (Exception e) {
            /* Read-only panel. Without this set the other two ways of knowing still
               answer, so the worst case is a row that offers a check the server then
               refuses in its own words - never a second submission, which that class
               stops on its own. */
        }
        return out;
    }

    private static void applyVerification(PartyDTO p, Account a) {
        if (p == null) {
            return;
        }
        if (a == null) {
            /* Under sharing this rep cannot see the account. Everything here is left
               NULL on purpose, including the status: NOT_SENT would be a statement
               about a record we could not read, and the panel renders no chip at all
               rather than one it cannot stand behind. */
            return;
        }

        p.verificationStatus  = SalesConsoleVerificationService.statusForParty(a);
        p.manuallyApproved    = SalesConsoleVerificationService.isManuallyApproved(a);
        p.verificationSentOn  = a.KYC_Send_Date_Time__c;
        p.canEverVerify       = (a.IsPersonAccount == true);

        if (!p.canEverVerify) {
            p.verificationBlockedReason =
                a.Name + ' is a company account. Identity verification for a company is '
                + 'handled by Sales Operations from the account record.';
            return;
        }
        if (a.PersonContactId == null) {
            p.verificationBlockedReason =
                a.Name + ' has no contact record yet, so a verification link cannot be '
                + 'sent. Sales Operations can put that right.';
            return;
        }

        List<String> missing = SalesConsoleVerificationService.missingForSend(a);
        if (!missing.isEmpty()) {
            p.detailsMissing = true;
            p.verificationBlockedReason =
                'Add ' + a.Name + '\'s ' + String.join(missing, ', ')
                + ' before sending the verification link.';
            return;
        }
        p.canSendVerification = true;
    }

    /**
     * The sentence about coverage, on a booking that HAS a joint owner.
     *
     * A single-unit booking gets nothing - there is no coverage question to answer. A
     * basket that somebody is co-owning gets a sentence whether the news is good or
     * bad, because a line that only appears when something is wrong teaches the rep to
     * read its absence as approval, and it is precisely that silence that left 33 units
     * in preprod with no co-owner on a booking where every other unit had one.
     *
     * 1.7 - AND A SOLE-OWNED BOOKING GETS NOTHING EITHER. "None of the 2 units has a
     * joint owner yet" was true of every booking nobody had co-owned, so it appeared on
     * all of them and reported the ordinary case as a shortfall - directly under a panel
     * that had just shown one owner holding 100%. Coverage is only a question once there
     * is somebody to spread across the units; until then there is nothing to report and
     * the Add button says everything that needs saying. That also retires the
     * none == total branch, which was the only way this could be reached with no joint
     * owner on the booking.
     */
    private static String coverage(OwnersDTO dto, Ctx c) {
        if (dto.jointOwnerCount == null || dto.jointOwnerCount == 0) {
            return null;
        }
        if (c.orderList.size() < 2) {
            return null;
        }
        Integer total = c.orderList.size();
        if (dto.unitsWithNoJointOwner.isEmpty()) {
            return 'All ' + total + ' units have a joint owner.';
        }
        Integer none = dto.unitsWithNoJointOwner.size();
        return none + (none == 1 ? ' unit has' : ' units have') + ' no joint owner - '
            + String.join(dto.unitsWithNoJointOwner, ', ') + '.';
    }

    // ======================================================================
    // the guards
    // ======================================================================

    /**
     * What is actually on these units, read WITHOUT sharing.
     *
     * Counts, share totals and the set of people already on each unit - nothing that is
     * ever rendered. See the class header: a guard that cannot see a record is not a
     * guard, and JointOwner__c is Private with a Read-only sharing rule, so under sharing
     * a rep could be waved through a seventh owner or a duplicate and left to meet
     * MODON's trigger instead, which reports on the wrong record.
     */
    private class Truth {
        Map<Id, Integer> counts  = new Map<Id, Integer>();
        Map<Id, Decimal> shares  = new Map<Id, Decimal>();
        Map<Id, Set<Id>> people  = new Map<Id, Set<Id>>();

        Integer countFor(Id orderId) {
            return counts.containsKey(orderId) ? counts.get(orderId) : 0;
        }
        Decimal shareFor(Id orderId) {
            return shares.containsKey(orderId) ? shares.get(orderId) : 0;
        }
        Boolean holds(Id orderId, Id contactId) {
            return contactId != null
                && people.containsKey(orderId)
                && people.get(orderId).contains(contactId);
        }
        /* 2.0 - MSC-180. The same question by ACCOUNT. A company has no
           PersonContactId, so the contact key above cannot see it - and MODON's own
           trigger skips companies in its duplicate check too, which makes this the
           only fence a company row has. For a person it is a strict superset of the
           contact test (one account, one contact), so no person answers differently. */
        Map<Id, Set<Id>> accounts = new Map<Id, Set<Id>>();
        Boolean holdsAccount(Id orderId, Id accountId) {
            return accountId != null
                && accounts.containsKey(orderId)
                && accounts.get(orderId).contains(accountId);
        }
    }

    private without sharing class Guard {
        Truth read(Set<Id> orderIds) {
            Truth t = new Truth();
            if (orderIds == null || orderIds.isEmpty()) {
                return t;
            }
            for (JointOwner__c jo : [
                SELECT Id, SalesOrder__c, OwnershipPercentage__c,
                       JointOwnerAccount__c, JointOwnerAccount__r.PersonContactId
                FROM JointOwner__c
                WHERE SalesOrder__c IN :orderIds
            ]) {
                Id so = jo.SalesOrder__c;
                t.counts.put(so, (t.counts.containsKey(so) ? t.counts.get(so) : 0) + 1);
                Decimal share = jo.OwnershipPercentage__c == null ? 0 : jo.OwnershipPercentage__c;
                t.shares.put(so, (t.shares.containsKey(so) ? t.shares.get(so) : 0) + share);
                if (!t.people.containsKey(so)) {
                    t.people.put(so, new Set<Id>());
                }
                if (jo.JointOwnerAccount__r != null
                        && jo.JointOwnerAccount__r.PersonContactId != null) {
                    t.people.get(so).add(jo.JointOwnerAccount__r.PersonContactId);
                }
                if (jo.JointOwnerAccount__c != null) { // 2.0 - MSC-180
                    if (!t.accounts.containsKey(so)) {
                        t.accounts.put(so, new Set<Id>());
                    }
                    t.accounts.get(so).add(jo.JointOwnerAccount__c);
                }
            }
            return t;
        }

        /** Is this person already the buyer or a joint owner anywhere on this booking? */
        Boolean onBooking(Id opportunityId, Id accountId) {
            Integer n = [
                SELECT COUNT()
                FROM JointOwner__c
                WHERE JointOwnerAccount__c = :accountId
                AND SalesOrder__r.Opportunity__c = :opportunityId
            ];
            if (n > 0) {
                return true;
            }
            return [SELECT COUNT() FROM Opportunity
                    WHERE Id = :opportunityId AND AccountId = :accountId] > 0;
        }
    }

    /** G2 - a cancelled, voided or SR-cancelled order is not a booking to write onto. */
    private static Boolean isDead(SalesOrder__c so) {
        return inSet(DEAD_ORDERS, so.Status__c);
    }

    /**
     * G3 - the cut-off, from three signals, any one of which closes it.
     *
     * SPAStatus__c is the ladder MODON actually maintains and is the primary signal.
     * SPA_Send_Date_for_Signature__c looks like the obvious gate and is not: it is
     * populated on 1,899 of 14,259 preprod orders, and 7,825 orders are past SPA
     * generation without one - 6,595 of them already signed by Modon. It is kept as a
     * second signal because when it IS set the envelope definitely went out, whatever
     * else says. Status__c is a third, and it earns its place: two preprod orders read a
     * signed status while SPAStatus__c still claims the SPA was never generated, and one
     * of them carries a joint owner.
     */
    private static String spaClosedReason(SalesOrder__c so) {
        String unit = unitNameOf(so);
        if (so.SPA_Send_Date_for_Signature__c != null) {
            return 'The SPA for ' + unit + ' was sent for signature on '
                + so.SPA_Send_Date_for_Signature__c.format() + ', so ' + SERVICE_REQUEST_ROUTE;
        }
        if (inSet(STATUS_SPA_OUT, so.Status__c)) {
            return 'The SPA for ' + unit + ' has already been sent to the customer, so '
                + SERVICE_REQUEST_ROUTE;
        }
        if (String.isNotBlank(so.SPAStatus__c) && !inSet(SPA_OPEN, so.SPAStatus__c)) {
            return 'The SPA for ' + unit + ' is at "' + so.SPAStatus__c + '", so '
                + SERVICE_REQUEST_ROUTE;
        }
        return null;
    }

    /** G2, G3, G10 - may anything at all be written to this unit? */
    private static void checkWritable(SalesOrder__c so) {
        if (inSet(new Set<String>{ EGYPT }, so.Source_Entity__c)) {
            throw refuse(
                'This is a Modon Egypt booking. Joint owners are added there from the '
                + 'Add Joint Owners screen on the Sales Order.'
            );
        }
        if (isDead(so)) {
            throw refuse(unitNameOf(so) + ' is no longer part of this booking.');
        }
        String why = spaClosedReason(so);
        if (why != null) {
            throw refuse(why);
        }
    }

    /** G4, G5, G6 - is there room for this person, at this share, on this unit? */
    private static void checkCapacity(SalesOrder__c so, Truth t, Account person, Decimal share) {
        String unit = unitNameOf(so);

        if (t.countFor(so.Id) >= MAX_OWNERS) {
            throw refuse(
                unit + ' already has the maximum of ' + MAX_OWNERS + ' joint owners.'
            );
        }
        if (t.holds(so.Id, person.PersonContactId)
                || t.holdsAccount(so.Id, person.Id)) { // 2.0 - the company's only fence
            throw refuse(
                person.Name + ' is already a joint owner on ' + unit + '.'
            );
        }
        Decimal held = t.shareFor(so.Id);
        if (held + share >= 100) {
            throw refuse(remainderMessage(unit, held));
        }
    }

    /** G6 for an edit: the person's own share is being replaced, not added. */
    private static void checkShareChange(SalesOrder__c so, Truth t, JointOwner__c row, Decimal share) {
        Decimal own = row.OwnershipPercentage__c == null ? 0 : row.OwnershipPercentage__c;
        Decimal others = t.shareFor(so.Id) - own;
        if (others + share >= 100) {
            throw refuse(remainderMessage(unitNameOf(so), others));
        }
    }

    /**
     * What is left, said as a number the rep can act on.
     *
     * MODON's own rule refuses at >= 100, not > 100, so the remainder is exclusive and
     * the sentence says "under", not "at most". Getting that word wrong would send the
     * rep round the loop once for nothing.
     */
    private static String remainderMessage(String unit, Decimal held) {
        Decimal room = 100 - held;
        if (room <= 0) {
            return 'The joint owners of ' + unit + ' already hold ' + strip(held)
                + '%. There is nothing left to allocate.';
        }
        return 'The joint owners of ' + unit + ' already hold ' + strip(held)
            + '%. This joint owner must be under ' + strip(room) + '%.';
    }

    /** G8 - a share outside this is not a share. */
    private static void checkShareRange(Decimal share) {
        if (share == null) {
            throw refuse('Enter this joint owner\'s Ownership %.');
        }
        if (share <= 0 || share >= 100) {
            throw refuse('Ownership % must be between 1 and 99.');
        }
    }

    /** G9 - both relationship fields, validated against describe rather than a copy. */
    private static void checkRelationship(String relType, String relSub) {
        if (String.isBlank(relType) || String.isBlank(relSub)) {
            throw refuse('Select a Relationship Type and Relationship Sub Type.');
        }
        if (!picklistHas('RelationshipType__c', relType)) {
            throw refuse('"' + relType + '" is not a valid Relationship Type.');
        }
        if (!picklistHas('RelationshipSubType__c', relSub)) {
            throw refuse('"' + relSub + '" is not a valid Relationship Sub Type.');
        }
    }

    /** G7, G11 - can this Account be a joint owner at all? */
    private static void checkPersonIsUsable(Account a) {
        if (a == null) {
            throw refuse('That person could no longer be found.');
        }
        if (a.IsPersonAccount != true) {
            throw refuse(
                'Only an individual can be added as a joint owner here. A company joint '
                + 'owner is handled by Sales Operations.'
            );
        }
        if (a.Is_Merged__c == true) {
            throw refuse(
                a.Name + ' was merged into another account. Use the surviving record.'
            );
        }
        if (String.isBlank(a.UAE_Resident_Status__pc)) {
            /* Not a nicety. SendEnvelope refuses the WHOLE envelope - buyer included -
               when any joint owner's resident status is blank, so a missing one here
               takes down the contract for the entire booking later. */
            throw refuse(
                'Set a Resident Status for ' + a.Name
                + ' - the SPA cannot be sent for signature without it.'
            );
        }
        if (a.PersonContactId == null) {
            throw refuse(
                a.Name + ' has no contact record yet, so they cannot be added. Sales '
                + 'Operations can put that right.'
            );
        }
    }

    /**
     * 2.0 - MSC-180. G7/G11 for a COMPANY account.
     *
     * Deliberately not the person list with branches: a company has no contact to
     * demand, no personal residency to require (SendEnvelope's refusal of exactly that
     * blank is the parked item, Sales Operations' path) - what it can be is merged, or
     * not a customer at all. The record-type fence matters because addOwner is a public
     * endpoint: the search can only return customer companies, but a crafted accountId
     * could name a broker agency, and a broker agency on a contract is not a data
     * problem, it is a legal one.
     */
    private static void checkCompanyIsUsable(Account a) {
        if (a == null) {
            throw refuse('That company could no longer be found.');
        }
        if (a.Is_Merged__c == true) {
            throw refuse(
                a.Name + ' was merged into another account. Use the surviving record.'
            );
        }
        String rtName = a.RecordType == null ? null : a.RecordType.DeveloperName;
        if (SalesConsoleLeadController.NON_CUSTOMER_ORG_RECORD_TYPES.contains(rtName)) {
            throw refuse(
                a.Name + ' is not a customer account, so it cannot be added as a joint owner.'
            );
        }
    }

    /** 2.0 - a company's relationship to the buyer is commercial, not kinship. */
    private static void checkCompanyRelationship(String relType) {
        if (!COMPANY_REL_TYPES.contains(relType)) {
            throw refuse(
                'A company joint owner\'s Relationship Type must be Partner or Third Party.'
            );
        }
    }

    /**
     * 2.0 - MSC-180. The company account: the one the rep picked, matched by licence,
     * or a new one.
     *
     * The same shape as resolveOrCreatePerson - match before create, so the window
     * between searching and saving cannot mint a duplicate - and the same WRITES as
     * SalesConsoleController.companyUpdate, which is the console's one existing author
     * of company identity: the licence lands in all three licence fields (UnifiedNumber__c
     * is the one Passfort sends), the name in both name fields. No third pattern.
     */
    private static Account resolveOrCreateCompany(Ctx c, AddOwnerInput input) {
        String name    = trimmed(input.companyName);
        String licence = trimmed(input.tradeLicence);
        if (String.isBlank(name)) {
            throw refuse('Company Name is required.');
        }
        if (String.isBlank(licence)) {
            throw refuse(
                'Enter a Trade Licence Number. Without one this company cannot be '
                + 'matched to an existing account.'
            );
        }
        Id existing = SalesConsoleLeadController.matchOrganisationAccount(licence);
        if (existing != null) {
            return loadPerson(existing);
        }
        Account a = new Account(
            Name = name,
            Company_Name_as_per_Trade_License__c = name,
            UnifiedNumber__c        = licence,
            TradeLicenseNumber__c   = licence,
            Trade_License_Number__c = licence,
            RecordTypeId = orgRecordTypeId()
        );
        /* allowSave, for resolveOrCreatePerson's reason: the licence match has already
           run and found nobody, so a duplicate rule here is warning about a name
           collision - the merge module's business, not a blocked contract. */
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.SaveResult sr = Database.insert(a, options);
        if (!sr.isSuccess()) {
            throw refuse(
                sr.getErrors().isEmpty()
                    ? 'That company could not be created.'
                    : friendly(sr.getErrors()[0].getMessage())
            );
        }
        return loadPerson(a.Id);
    }

    /**
     * The record type a company created here gets. ALWAYS the org's standard customer
     * one - never the buyer's, unlike personRecordTypeId: 6 of DEV_1's corporate
     * buyers are broker agencies and 86 carry no record type at all, and a co-owning
     * company is a customer whatever the buyer happens to be.
     */
    private static Id orgRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = :ORG_RT
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    /** G5, the other branch - the buyer is not their own joint owner. */
    private static void checkNotTheBuyer(Ctx c, Account person) {
        if (person.Id == c.buyer.Id
                || (c.buyerContactId != null && person.PersonContactId == c.buyerContactId)) {
            throw refuse(
                person.Name + ' is the primary owner on this booking and cannot also be a joint owner.'
            );
        }
    }

    // ======================================================================
    // the person
    // ======================================================================

    /**
     * The co-owner's Account: the one the rep picked, or a new one.
     *
     * NOT a Lead conversion. The console creates buyers with
     * Database.convertLead(setDoNotCreateOpportunity(false)), which mints an Opportunity
     * - correct for a buyer, wrong for a co-owner, who is not starting a booking of their
     * own. So the Person Account is inserted directly.
     *
     * The document search runs again here even though the panel has already run it. It is
     * cheap, and it closes the window between the rep searching and the rep saving. 2.2: a
     * match is no longer used silently; see the block below.
     */
    private static Account resolveOrCreatePerson(Ctx c, AddOwnerInput input) {
        if (input.accountId != null) {
            return loadPerson(input.accountId);
        }

        String first = trimmed(input.firstName);
        String last  = trimmed(input.lastName);
        String eid   = trimmed(input.eidNumber);
        String pass  = trimmed(input.passportNumber);

        if (String.isBlank(last)) {
            throw refuse('Last Name is required.');
        }
        if (String.isBlank(input.residentStatus)) {
            throw refuse(
                'Select a Resident Status - the SPA cannot be sent for signature without it.'
            );
        }
        if (String.isBlank(eid) && String.isBlank(pass)) {
            throw refuse(
                'Enter an Emirates ID Number or Passport Number. Without one this person cannot '
                + 'be matched to an existing account.'
            );
        }
        /* 2.3 - restricted picklists: a value off the list is refused here, not by the insert */
        String nationality = nationalityValue(input.nationality);
        String residency   = residentStatusValue(input.residentStatus);

        /* 2.2 - THE BUYER'S MATCH, AND THE REP CHOOSES (28 Sep 2026).
         *
         * 1.9 asked the document question and then the email or mobile one, and quietly reused a
         * single answer. A buyer meets a chooser instead: SalesConsoleLeadController's matchCandidates,
         * Emirates ID or passport first, email or mobile (UAE spellings) only when no document
         * matched, merged accounts left out. The joint owner now meets the same rule through the same
         * method, so the two cannot drift. Any match stops the create and nothing is written:
         * createPerson hands the matches to the rep, addOwner refuses. A new person despite a match
         * is created only when the rep asks for it AND ALLOW_NEW_CUSTOMER_DESPITE_MATCH is on; with it
         * off the refusal is the Sales App's own sentence, as for a buyer (SCW-205). */
        List<Account> matches = SalesConsoleLeadController.matchPersonCandidates(
            eid, pass, trimmed(input.email), trimmed(input.mobile));
        if (!matches.isEmpty()) {
            if (input.createDespiteMatch != true) {
                MatchesFoundException found =
                    new MatchesFoundException(SalesConsoleLeadController.MATCH_MUST_BE_CHOSEN);
                found.matches = matches;
                throw found;
            }
            if (!AurelixNewCustomerSwitch.isOn()) {
                throw refuse(SalesConsoleLeadController.MATCH_MUST_BE_CHOSEN);
            }
            /* the switch is on and the rep chose a new person: created below */
        }

        Account a = new Account(
            FirstName               = first,
            LastName                = last,
            PersonEmail             = trimmed(input.email),
            PersonMobilePhone       = trimmed(input.mobile),
            Nationality__pc         = nationality,
            UAE_Resident_Status__pc = residency,
            RecordTypeId            = personRecordTypeId(c)
        );
        /* 1.10 - ONE FIELD, CHOSEN BY SHAPE. NEVER BOTH. MSC-178.
         *
         * c/mscOwnersDrawer sends the rep's single number as BOTH eidNumber and
         * passportNumber, deliberately: "the rep typed the number in front of them;
         * they should never have to be right about which box it belongs in". That is
         * the correct thing for the CLIENT to do - and this method was meant to be
         * the half that decides. It never decided. It tested each argument for
         * blankness and wrote both, so every co-owner created here got the same
         * string filed as an Emirates ID AND as a passport.
         *
         * Two accounts in DEV_1 carry the damage: Testing Joint2939 holds a real
         * Emirates ID in PassportNumber__pc, and Abdul Rahman142342 holds an
         * eight-digit passport in EIDNumber__pc.
         *
         * It is not cosmetic. matchAccountByDocument searches both fields, so a
         * passport number matching on somebody's Emirates ID is exactly the
         * cross-document collision MSC-172 widened the matchers to avoid.
         *
         * Fifteen digits is an Emirates ID and nothing else is - the UAE format is
         * 3-4-7-1, the same rule SalesConsoleLeadController.docVariants rebuilds
         * separated numbers with, so the two classes agree on what an Emirates ID
         * looks like. Anything else is a passport: they have no fixed shape, which
         * is why they are the fallback and not the test.
         *
         * The SEARCH above still passes both and still looks in both fields. Only
         * the WRITE narrows - a number the rep may have mis-filed should still find
         * whoever holds it. */
        String docDigits = eid == null ? '' : eid.replaceAll('[^0-9]', '');
        if (String.isNotBlank(eid) && docDigits.length() == 15) {
            a.EIDNumber__pc = eid;
        } else if (String.isNotBlank(pass)) {
            a.PassportNumber__pc = pass;
        } else if (String.isNotBlank(eid)) {
            /* The drawer sends both, so this is unreachable from the console - but
               addOwner is public and a caller supplying only an oddly-shaped eid
               must still land its value somewhere rather than silently lose it. */
            a.PassportNumber__pc = eid;
        }

        /* allowSave, matching SalesConsoleVerificationService.stampUnitContext and
           SalesConsoleLeadController's own reasoning: the document search has already
           run and found nobody, so what a duplicate rule is warning about here is a
           name or an email collision, which is a data problem for the merge module to
           settle later. A blocked joint owner is a contract that cannot be signed. */
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.SaveResult sr = Database.insert(a, options);
        if (!sr.isSuccess()) {
            throw refuse(
                sr.getErrors().isEmpty()
                    ? 'That person could not be created.'
                    : friendly(sr.getErrors()[0].getMessage())
            );
        }
        return loadPerson(a.Id);
    }

    /**
     * 1.2 - FILLS WHAT IS BLANK ON A JOINT OWNER'S ACCOUNT. NOTHING ELSE, EVER.
     *
     * WHY THIS EXISTS. Adding a joint owner needs a last name, a Resident Status and one
     * document - the right bar for putting a co-owner on a contract, and deliberately
     * low so that a correct booking is never harder to enter than a careless one.
     * Sending that person an identity verification link needs four more things.
     * Without this method the console can therefore show a person it can never verify,
     * and the rep's only route is to leave the console for the Account record - which is
     * exactly the kind of gap that leaves 2,236 joint owners in the org and 101 of them
     * verified.
     *
     * WHY IT ONLY FILLS BLANKS. This is a MODON Account, quite possibly the buyer of
     * somebody else's booking, and it is not ours to correct. An overwrite would put a
     * mistyped mobile number over a good one with nothing anywhere to say it happened.
     * A blank field has no such risk: there is nothing to lose and the record is
     * strictly better off. So a populated field is left exactly as it is, and the drawer
     * shows it disabled rather than offering a box that would silently discard what was
     * typed into it.
     *
     * It issues NO DML at all when there is nothing to fill, which is the ordinary case
     * on every subsequent edit.
     *
     * @return the account as it now stands, re-read so the checks after this see it.
     */
    private static Account fillBlankContactDetails(Account person, UpdateOwnerInput input) {
        if (person == null || input == null) {
            return person;
        }
        /* Company and merged accounts are checkPersonIsUsable's to refuse, and it runs
           immediately after this. Writing to one first would be a change made to a
           record we are about to reject. */
        if (person.IsPersonAccount != true || person.Is_Merged__c == true) {
            return person;
        }

        Account patch = new Account(Id = person.Id);
        Boolean filled = false;
        if (String.isBlank(person.PersonEmail) && String.isNotBlank(trimmed(input.email))) {
            patch.PersonEmail = trimmed(input.email);
            filled = true;
        }
        if (String.isBlank(person.PersonMobilePhone) && String.isNotBlank(trimmed(input.mobile))) {
            patch.PersonMobilePhone = trimmed(input.mobile);
            filled = true;
        }
        /* 2.3 - restricted picklists: matched to the list, or refused before the update */
        if (String.isBlank(person.Nationality__pc) && String.isNotBlank(trimmed(input.nationality))) {
            patch.Nationality__pc = nationalityValue(input.nationality);
            filled = true;
        }
        if (String.isBlank(person.UAE_Resident_Status__pc)
                && String.isNotBlank(trimmed(input.residentStatus))) {
            patch.UAE_Resident_Status__pc = residentStatusValue(input.residentStatus);
            filled = true;
        }
        if (!filled) {
            return person;
        }

        /* allowSave, for the reason resolveOrCreatePerson and stampUnitContext both
           record: a duplicate rule that only warns must not stop a field-level fill on
           an account that already exists. */
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.SaveResult sr = Database.update(patch, options);
        if (!sr.isSuccess()) {
            throw refuse(
                sr.getErrors().isEmpty()
                    ? 'Those details could not be saved against ' + person.Name + '.'
                    : friendly(sr.getErrors()[0].getMessage())
            );
        }
        return loadPerson(person.Id);
    }

    /**
     * 1.6 - MSC-091. Refuses a change to somebody whose verification is already under
     * way.
     *
     * "Under way" is anything but NOT_SENT - sent, expired, or verified. An expired
     * link counts because it was still sent against these details and the move is to
     * resend, not to edit; a verified person counts because their identity has been
     * confirmed against exactly what is on the record.
     *
     * A person this rep cannot read is left to checkPersonIsUsable, which refuses it
     * with its own sentence a line later.
     */
    private static void checkNotAlreadySent(Account person) {
        if (person == null) {
            return;
        }
        String status = SalesConsoleVerificationService.statusForParty(person);
        if (status != null && !SalesConsoleVerificationService.NOT_SENT.equals(status)) {
            throw refuse(editSentReason(person.Name));
        }
    }

    /* 2.4: without sharing (PersonLookup), so a found person is shown whoever owns the account */
    private static Account loadPerson(Id accountId) {
        return new PersonLookup().read(accountId);
    }

    /**
     * 2.4. The joint owner's account, read without sharing: every rep sees every customer, as in the
     * Sales App. The fields are the ones the person card and the guards already used.
     */
    private without sharing class PersonLookup {
        Account read(Id accountId) {
            if (accountId == null) {
                return null;
            }
            List<Account> accs = [
                SELECT Id, Name, IsPersonAccount, Is_Merged__c, PersonContactId,
                       UAE_Resident_Status__pc, RecordTypeId,
                       /* 2.0 - MSC-180. What checkCompanyIsUsable asks: a crafted
                          accountId must not put a broker agency on a contract. */
                       RecordType.DeveloperName,
                       /* 1.2 - read so fillBlankContactDetails can tell a blank field from
                          a populated one. Deciding that from the DTO the browser sent back
                          would be trusting the client with what it may overwrite. */
                       PersonEmail, PersonMobilePhone, Nationality__pc,
                       /* 1.6 - MSC-091. The four fields statusForParty reads, so the write
                          can ask the same question the panel asked. */
                       KYC_Send_Date_Time__c, Is_KYC_Link_Active__c,
                       KYC_Completed_Date__c, KYC_Link_Status__c, Manual_KYC_Approval__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            return accs.isEmpty() ? null : accs[0];
        }
    }

    /**
     * The record type the co-owner gets.
     *
     * The buyer's own, when there is one. A co-owner is the same kind of party as the
     * buyer, and taking it from the record in front of us survives an org that has more
     * than one person-account record type - which a DeveloperName lookup does not.
     */
    private static Id personRecordTypeId(Ctx c) {
        /* 2.0 - MSC-180. ONLY a person buyer's record type is a person record type.
           This method's premise - "a co-owner is the same kind of party as the buyer" -
           was written when a company buyer could not reach it. Under one, the old line
           would hand the ORGANISATION record type to a newly created individual, and
           the insert of PersonEmail/FirstName against it would fail in DML. */
        if (c != null && c.buyer != null && c.buyer.RecordTypeId != null
                && c.buyer.IsPersonAccount == true) {
            return c.buyer.RecordTypeId;
        }
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE SobjectType = 'Account' AND DeveloperName = :PERSON_RT
            LIMIT 1
        ];
        return rts.isEmpty() ? null : rts[0].Id;
    }

    // ======================================================================
    // the write
    // ======================================================================

    /**
     * The junction row, and only the junction row.
     *
     * Opportunity__c is deliberately absent. The before-save Flow
     * Joint_Owner_Before_Created_Updated reads the Sales Order and stamps it, and a
     * before-save Flow runs ahead of any before-trigger, so setting it here would only
     * make two authors of one field.
     */
    private static JointOwner__c buildRow(
        Id salesOrderId, Id accountId, Decimal share, String relType, String relSub
    ) {
        return new JointOwner__c(
            JointOwnerAccount__c   = accountId,
            SalesOrder__c          = salesOrderId,
            OwnershipPercentage__c = share,
            RelationshipType__c    = relType,
            RelationshipSubType__c = relSub
        );
    }

    /**
     * Which units this write covers.
     *
     * An empty request means every OPEN unit, and that default is the whole point: the
     * common case in the data is one co-owner across the whole basket, so it should cost
     * no decision, while putting one person on one unit stays possible and deliberate.
     */
    private static List<SalesOrder__c> resolveTargets(Ctx c, List<Id> requested) {
        List<SalesOrder__c> out = new List<SalesOrder__c>();

        if (requested == null || requested.isEmpty()) {
            for (SalesOrder__c so : c.orderList) {
                if (!inSet(new Set<String>{ EGYPT }, so.Source_Entity__c)
                        && spaClosedReason(so) == null) {
                    out.add(so);
                }
            }
            if (out.isEmpty()) {
                throw refuse(
                    'No unit on this booking will accept a joint owner any more. '
                    + 'Raise a Joint Owner Addition service request.'
                );
            }
            return out;
        }

        Set<Id> seen = new Set<Id>();
        for (Id id : requested) {
            if (id == null || seen.contains(id)) {
                continue;
            }
            seen.add(id);
            SalesOrder__c so = c.orders.get(id);
            if (so == null) {
                throw refuse('One of those units is not part of this booking.');
            }
            out.add(so);
        }
        if (out.isEmpty()) {
            throw refuse('Select at least one unit.');
        }
        return out;
    }

    /** Said after a successful write, not instead of one. See SPA_WARN. */
    private static String staleSpaWarning(List<SalesOrder__c> orders) {
        List<String> names = new List<String>();
        for (SalesOrder__c so : orders) {
            if (inSet(new Set<String>{ SPA_WARN }, so.SPAStatus__c)) {
                names.add(unitNameOf(so));
            }
        }
        if (names.isEmpty()) {
            return null;
        }
        Boolean one = names.size() == 1;
        return 'The SPA for ' + String.join(names, ', ') + (one ? ' has' : ' have')
            + ' already been generated. ' + (one ? 'It has' : 'They have')
            + ' to be regenerated before going to the customer.';
    }

    private static Boolean isAlreadyOnBooking(Id opportunityId, Id accountId) {
        return new Guard().onBooking(opportunityId, accountId);
    }

    // ======================================================================
    // small helpers
    // ======================================================================

    /**
     * Case-insensitive membership, used for every status comparison in this class.
     *
     * The org stores 'System cancelled'; every hand-written set in this codebase spells
     * it 'System Cancelled'; Set<String>.contains is case-sensitive. That combination is
     * already a live latent bug elsewhere, and one helper is how this class avoids
     * repeating it. The sets are small enough that the linear scan costs nothing.
     */
    private static Boolean inSet(Set<String> values, String candidate) {
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

    private static Map<String, Set<String>> PICKLIST_CACHE = new Map<String, Set<String>>();

    private static Set<String> picklistValues(String fieldApi) {
        if (!PICKLIST_CACHE.containsKey(fieldApi)) {
            Set<String> vals = new Set<String>();
            Schema.SObjectField f = Schema.SObjectType.JointOwner__c.fields.getMap().get(fieldApi);
            if (f != null) {
                for (Schema.PicklistEntry e : f.getDescribe().getPicklistValues()) {
                    if (e.isActive()) {
                        vals.add(e.getValue());
                    }
                }
            }
            PICKLIST_CACHE.put(fieldApi, vals);
        }
        return PICKLIST_CACHE.get(fieldApi);
    }

    private static Boolean picklistHas(String fieldApi, String value) {
        return inSet(picklistValues(fieldApi), value);
    }

    /** The choices the form offers, read from the field rather than listed here. */
    private static List<OptionDTO> options(String fieldApi) {
        List<OptionDTO> out = new List<OptionDTO>();
        Schema.SObjectField f = Schema.SObjectType.JointOwner__c.fields.getMap().get(fieldApi);
        if (f == null) {
            return out;
        }
        for (Schema.PicklistEntry e : f.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                out.add(new OptionDTO(e.getValue()));
            }
        }
        return out;
    }

    private static Set<Id> orderIds(List<SalesOrder__c> orders) {
        Set<Id> ids = new Set<Id>();
        for (SalesOrder__c so : orders) {
            ids.add(so.Id);
        }
        return ids;
    }

    /** What the rep calls this unit. The booking reference is the fallback, not the name. */
    private static String unitNameOf(SalesOrder__c so) {
        if (so == null) {
            return 'this unit';
        }
        if (so.Unit__r != null && String.isNotBlank(so.Unit__r.Name)) {
            return so.Unit__r.Name;
        }
        return String.isNotBlank(so.Name) ? so.Name : 'this unit';
    }

    private static String trimmed(String s) {
        return String.isBlank(s) ? null : s.trim();
    }

    /* 2.3 - the refusals for a value that is not on the field's list */
    @TestVisible
    private static final String NATIONALITY_NOT_LISTED = 'Choose a Nationality from the list.';
    @TestVisible
    private static final String RESIDENCY_NOT_LISTED = 'Choose Resident or Non-Resident.';

    /** 2.3 - Nationality__pc as the list spells it; null when blank; refused when not listed. */
    private static String nationalityValue(String raw) {
        return listedValue(Account.Nationality__pc.getDescribe(), raw, NATIONALITY_NOT_LISTED);
    }

    /** 2.3 - UAE_Resident_Status__pc as the list spells it; null when blank; refused when not listed. */
    private static String residentStatusValue(String raw) {
        return listedValue(Account.UAE_Resident_Status__pc.getDescribe(), raw, RESIDENCY_NOT_LISTED);
    }

    /**
     * 2.3 - The field's active value matching `raw` (case ignored), as the field spells it, so the
     * insert cannot fail on a restricted picklist. Anything else is refused with `refusal`.
     */
    private static String listedValue(Schema.DescribeFieldResult field, String raw, String refusal) {
        String v = trimmed(raw);
        if (v == null) {
            return null;
        }
        for (Schema.PicklistEntry e : field.getPicklistValues()) {
            if (e.isActive() && e.getValue().equalsIgnoreCase(v)) {
                return e.getValue();
            }
        }
        throw refuse(refusal);
    }

    /** 70.00 reads as 70. A percentage with cents on it looks like a bug. */
    private static String strip(Decimal d) {
        if (d == null) {
            return '0';
        }
        Decimal s = d.setScale(2, System.RoundingMode.HALF_UP);
        return s.setScale(0, System.RoundingMode.HALF_UP) == s
            ? String.valueOf(s.longValue())
            : String.valueOf(s);
    }

    /**
     * A refusal the rep can read - and that a debug log and a test can read too.
     *
     * AuraHandledException carries its message to the client through the constructor,
     * but getMessage() answers "Script-thrown exception" in Apex until setMessage is
     * called. Every refusal in this class is a sentence written for a person, and a
     * sentence nobody can read in a log or assert on in a test is half a sentence. So
     * they are all built here.
     */
    private static AuraHandledException refuse(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /** A platform message the rep can do nothing with, turned into one they can. */
    private static String friendly(String raw) {
        if (String.isBlank(raw)) {
            return 'Something went wrong. Please try again.';
        }
        String m = raw.toLowerCase();
        if (m.contains('insufficient access') || m.contains('insufficient_access')) {
            return 'You do not have access to change that joint owner. It was added by someone else - '
                + 'ask them, or Sales Operations.';
        }
        if (m.contains('unable to lock row')) {
            return 'This booking is being updated by another process. Please try again in a moment.';
        }
        if (m.contains('maximum limit reached for joint owner')) {
            return 'That unit already has the maximum of ' + MAX_OWNERS + ' joint owners.';
        }
        if (m.contains('duplicate joint owner')) {
            return 'That person is already a joint owner on one of these units.';
        }
        if (m.contains('ownership percentage cannot be more than 100')) {
            return 'That Ownership % would take this unit to 100% or more.';
        }
        if (m.contains('field_custom_validation_exception') || m.contains('field integrity')) {
            return 'One of these details was not accepted. Please check it and try again.';
        }
        return raw;
    }
}