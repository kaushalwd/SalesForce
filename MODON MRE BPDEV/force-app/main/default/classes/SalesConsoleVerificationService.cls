/**
 * Identity verification for the Sales Console booking journey.
 *
 * Version  Author              Date         Detail
 * 1.x+2    Aurelix Dev  29 Sep 2026  A company buyer reads verified once its primary contact (the Power of
 *                                    Attorney) has finished KYC or is manually approved, as MODON's
 *                                    checkKYCEligibility; isVerified used to read only the company account.
 * 1.x+1    Aurelix Dev  27 Sep 2026  isManuallyApproved refuses a company account's own approval
 *                                    (27 Sep, after MODON's answer of 26 Sep). A company
 *                                    is approved on its Power of Attorney Contact only, as in
 *                                    MODON's checkKYCEligibility 18.1. A company buyer or company
 *                                    joint owner no longer shows as verified from an approval
 *                                    left on the company record before 21 Sep.
 * 1.x      Aurelix Dev  18 Sep 2026  isVerifiedAccount also accepts Manual_KYC_Approval__c = Approved
 *                                    (isManuallyApproved); the Verification step no longer reads a
 *                                    manually approved buyer as "no link sent yet".
 * 1.0      Aurelix Developer   16 Aug 2026  Initial. The step-2 verification choice
 *                                           and the gate that holds the journey until
 *                                           the customer has verified.
 * 1.1      Aurelix Developer   16 Aug 2026  Releasing the gate now raises a follow-up
 *                                           Task on the Opportunity, owned by its
 *                                           owner. The checkbox recorded that a
 *                                           booking went ahead unverified; nothing
 *                                           asked anyone to finish the job.
 * 1.3      Aurelix Developer   19 Aug 2026  SENDING THE LINK COMPLETES THE REP'S PART.
 *                                           By Modon's direction the journey is no
 *                                           longer held while a sent link is out:
 *                                           blocksAdvance answers false once a link
 *                                           was sent (HOLDS_WHILE_LINK_OUT), the
 *                                           Verification step reads complete on
 *                                           "KYC link sent", and the customer's own
 *                                           completion (and compliance) follow on
 *                                           their clock. Nothing else moves:
 *                                           statusFor still says SENT / EXPIRED /
 *                                           VERIFIED, releaseToBranch and its
 *                                           follow-up Task still work, and a rep who
 *                                           never sent a link is untouched.
 * 1.4      Aurelix IT          20 Aug 2026  MSC-082. VERIFICATION IS PER PERSON, NOT PER
 *                                           BOOKING. Everything downstream already was -
 *                                           enqueueSend, SendKycLinkJob and MODON's own
 *                                           sendKYCForm all take an Account Id - so what
 *                                           was missing was only the way in for a party
 *                                           who is not the buyer. Three additions, no
 *                                           behaviour changed for the buyer:
 *                                           isVerified(Account) extracted so one
 *                                           definition of "verified" serves both;
 *                                           statusForParty and missingForSend, read by
 *                                           SalesConsoleJointOwnerService; and
 *                                           stampUnitContextForParty, sharing ONE body
 *                                           with the opportunity form so the buyer's
 *                                           stamp is provably the same code it was.
 * 1.2      Aurelix Developer   17 Aug 2026  The follow-up Task's subject joins the
 *                                           customer's name with a plain hyphen, not an
 *                                           em dash: the console's notification bell
 *                                           lists Task subjects verbatim, and no em dash
 *                                           reaches a rep anywhere in the console now.
 *                                           The subject still starts with the same
 *                                           text, so the open-task de-duplication
 *                                           (LIKE 'Complete identity verification%')
 *                                           is unaffected.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * INTERNAL TO AURELIX. Called only from SalesConsoleController.
 *
 * Apex cannot express "only class X may call me", so the contract is enforced by
 * removing every other door rather than by guarding this one:
 *
 *   LWC / Aura      no @AuraEnabled METHOD here. The LWC calls
 *                   SalesConsoleController, which delegates.
 *   Flow            no @InvocableMethod.
 *   REST / SOAP     `public`, never `global`.
 *   Other namespace `public` is namespace-scoped.
 *
 * That leaves in-namespace Apex, which is code review's job. A runtime allow-list
 * parsed out of getStackTraceString() was considered and rejected: it matches on
 * an undocumented string format and breaks silently on a rename, which buys the
 * appearance of enforcement and costs a debugging session.
 *
 * @AuraEnabled appears below only on DTO FIELDS, which is what lets the wrapper
 * cross to the LWC. It does not make anything here callable.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * WHAT THIS TALKS TO, AND WHAT IT NEVER TOUCHES.
 *
 * MODON own the verification pipeline: CustomerKYCHandler.sendKYCForm creates the
 * Signzy journey, writes the link, and raises the flag their Flow sends the email
 * on. None of it is modified here. This class decides WHEN that call happens, what
 * context the customer's form carries, and whether the booking may proceed without
 * it.
 */
public with sharing class SalesConsoleVerificationService {

    /* The state a booking's verification is in. Ordered as the journey meets them. */
    public static final String NOT_SENT  = 'NOT_SENT';
    public static final String SENDING   = 'SENDING';
    public static final String SENT      = 'SENT';
    public static final String EXPIRED   = 'EXPIRED';
    public static final String VERIFIED  = 'VERIFIED';
    public static final String IN_BRANCH = 'IN_BRANCH';
    public static final String BLOCKED   = 'BLOCKED';

    /**
     * WHICH FIELDS ANSWER "HAS A LINK BEEN SENT, AND DID THEY FINISH IT".
     *
     * Checked against the org's own data rather than chosen by name, because three
     * of the obvious candidates are wrong:
     *
     *   SignzyURL__c / __pc            populated on ZERO records. Superseded by
     *                                  KYCSiteLink__pc and never removed.
     *   Send_KYC_Verification_Email__c TRUE on zero records. MODON's Flow clears it
     *                                  the moment it sends, so it is a trigger, not
     *                                  a state, and cannot answer "was it sent".
     *   Signzy_Journey_Status__c       stale. All 17 populated records read
     *                                  'IN PROGRESS', including accounts whose
     *                                  KYC_Response__c says COMPLETED. Nothing ever
     *                                  writes a terminal value to it.
     *
     * What is left, and is maintained: KYC_Send_Date_Time__c (17 records),
     * KYC_Link_Status__c (7), KYC_Completed_Date__c (12), and the two formulas
     * Is_KYC_Link_Active__c / KYC_Link_Expiry_At__c which carry the expiry.
     */
    private static Opportunity loadOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        List<Opportunity> opps = [
            SELECT Id, AccountId, Verification_In_Branch__c,
                   Account.IsPersonAccount,
                   Account.KYCSiteLink__pc,
                   Account.KYC_Send_Date_Time__c,
                   Account.KYC_Link_Status__c,
                   Account.KYC_Completed_Date__c,
                   Account.Is_KYC_Link_Active__c,
                   Account.KYC_Link_Expiry_At__c,
                   /* 1.x+2 - a company is verified on its primary contact */
                   PrimaryContact__r.KYC_Completed_Date__c,
                   PrimaryContact__r.Manual_KYC_Approval__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }

    /**
     * Verified means the customer finished the journey, by either of the two
     * signals the pipeline writes.
     *
     * Both are checked rather than one: updateKycInfoToAccount stamps
     * KYC_Completed_Date__c, while KYC_Link_Status__c is written from the Signzy
     * status poll, and the org's data shows 12 records with the date against 7 with
     * the status. Treating either as sufficient means a customer who genuinely
     * verified is never held by a signal that happened not to land.
     */
    public static Boolean isVerified(Opportunity opp) {
        if (isVerifiedAccount(opp == null ? null : opp.Account)) {
            return true;
        }
        /* 1.x+2 - a company is verified on its primary contact */
        return companyVerifiedOnPrimaryContact(opp);
    }

    /**
     * 1.x+2 - a company buyer is verified on its primary contact: a KYC completion date or a manual
     * approval, as MODON's checkKYCEligibility. False for a person, or when the contact is missing
     * or was not read.
     */
    @TestVisible
    private static Boolean companyVerifiedOnPrimaryContact(Opportunity opp) {
        if (opp == null || opp.Account == null) {
            return false;
        }
        Account a = opp.Account;
        if (!a.isSet('IsPersonAccount') || a.IsPersonAccount == true) {
            return false;
        }
        Contact c;
        try {
            c = (Contact) opp.getSObject('PrimaryContact__r');
        } catch (Exception e) {
            return false;
        }
        if (c == null) {
            return false;
        }
        if (c.isSet('KYC_Completed_Date__c') && c.KYC_Completed_Date__c != null) {
            return true;
        }
        return c.isSet('Manual_KYC_Approval__c')
            && 'Approved'.equalsIgnoreCase(c.Manual_KYC_Approval__c);
    }

    /**
     * 1.4 - the same question, asked of one Account.
     *
     * Extracted rather than copied. A joint owner goes through the identical Signzy
     * pipeline and writes back to their own Account, so "verified" must mean exactly
     * the same thing for them as for the buyer; two implementations would drift the
     * first time either signal changed, and the panel and the chain in the same card
     * would then disagree about one person.
     *
     * Named rather than overloaded on isVerified(Opportunity): the two would be
     * ambiguous for a literal null, and a compile error at some future call site is a
     * poor price for one shared word.
     */
    public static Boolean isVerifiedAccount(Account a) {
        if (a == null) {
            return false;
        }
        return a.KYC_Completed_Date__c != null
            || 'COMPLETED'.equalsIgnoreCase(a.KYC_Link_Status__c)
            || isManuallyApproved(a);
    }

    /**
     * 18 Sep 2026 (found in testing): a MANUAL KYC approval is the parallel route the booking
     * gate accepts (Manual_KYC_Approval__c = Approved, no completion date, never expires), so the
     * Verification track must read it as identity done rather than "no link sent yet". Guarded
     * with isSet so a caller whose query does not carry the field falls back to the two signals
     * above instead of throwing.
     */
    public static Boolean isManuallyApproved(Account a) {
        if (a == null || !a.isSet('Manual_KYC_Approval__c')) {
            return false;
        }
        /* 27 Sep 2026: a company's approval lives on its POA Contact, never on the company
           Account. Every caller that can pass a company reads IsPersonAccount; one that did not
           read it only ever passes a person, so an unread flag keeps the old answer. */
        if (a.isSet('IsPersonAccount') && a.IsPersonAccount != true) {
            return false;
        }
        return 'Approved'.equalsIgnoreCase(a.Manual_KYC_Approval__c);
    }

    /**
     * THE GATE. True while the journey must not advance past the customer step.
     *
     * It arms only when a link was actually sent - a rep who chose to carry on
     * without sending, and every existing customer, is unaffected. That is
     * deliberate: this feature must not change the behaviour of any flow that works
     * today.
     *
     * An EXPIRED link still holds the gate. Expiry means the customer did not
     * verify, which is precisely the case the gate exists for; the way out is
     * releaseToBranch, not an automatic pass after a timer.
     */
    public static Boolean blocksAdvance(Opportunity opp) {
        if (!HOLDS_WHILE_LINK_OUT) {
            /* 1.3 - the gate is stood down: sending the link is the rep's part of
               verification, and the booking goes on while the customer finishes on
               their phone. The rest of this method is kept as written so the hold can
               be restored by one constant should Modon ask for it back. */
            return false;
        }
        if (opp == null || opp.Account == null) {
            return false;
        }
        if (opp.Verification_In_Branch__c == true) {
            return false;
        }
        if (opp.Account.KYC_Send_Date_Time__c == null) {
            return false;
        }
        return !isVerified(opp);
    }

    /* 1.3 - see blocksAdvance. False by Modon's direction of 19 Aug 2026. */
    private static final Boolean HOLDS_WHILE_LINK_OUT = false;

    public static Boolean blocksAdvance(Id opportunityId) {
        return blocksAdvance(loadOpportunity(opportunityId));
    }

    /** NOT_SENT / SENT / EXPIRED / VERIFIED / IN_BRANCH, for the strip and the tape. */
    public static String statusFor(Opportunity opp) {
        if (opp == null || opp.Account == null) {
            return NOT_SENT;
        }
        /* Verified outranks released: a customer who was let through and then
           finished anyway has finished, and the screen should say so. */
        if (isVerified(opp)) {
            return VERIFIED;
        }
        if (opp.Verification_In_Branch__c == true) {
            return IN_BRANCH;
        }
        if (opp.Account.KYC_Send_Date_Time__c == null) {
            return NOT_SENT;
        }
        return opp.Account.Is_KYC_Link_Active__c == true ? SENT : EXPIRED;
    }

    /**
     * 1.4 - NOT_SENT / SENT / EXPIRED / VERIFIED for one party of a booking.
     *
     * The same four states in the same order as statusFor, read from that person's own
     * Account. What is deliberately ABSENT is IN_BRANCH: releasing someone to the
     * branch writes Opportunity.Verification_In_Branch__c, which is one flag for the
     * whole booking and belongs to the buyer, and the follow-up Task it raises names
     * the customer. Reporting IN_BRANCH for a joint owner would claim a decision
     * nobody made about them; offering the release for a joint owner would invent a
     * process Modon does not run. Both stay buyer-only.
     *
     * BLOCKED is absent for the same reason it is unused above - nothing writes it.
     */
    public static String statusForParty(Account a) {
        if (a == null) {
            return NOT_SENT;
        }
        if (isVerifiedAccount(a)) {
            return VERIFIED;
        }
        if (a.KYC_Send_Date_Time__c == null) {
            return NOT_SENT;
        }
        return a.Is_KYC_Link_Active__c == true ? SENT : EXPIRED;
    }

    /**
     * 1.4 - WHAT THIS PERSON IS STILL MISSING BEFORE A LINK CAN BE SENT.
     *
     * MODON's CustomerKYCHandler.sendKYCForm reports a missing field by RETURNING a
     * label rather than throwing, and inside SendKycLinkJob that string has nowhere to
     * go - so its preconditions have to be mirrored synchronously wherever a Send
     * button is offered, or the rep presses a control that silently does nothing.
     *
     * THE RULE, NOT THE SENTENCE. This returns field names because the sentence has to
     * name the person: "Add the customer's email address" is right in the verification
     * chain and wrong on a joint owner's row. Each caller composes its own line from
     * the same list, so the two can differ in wording and never in meaning.
     *
     * SalesConsoleController.getComplianceState carries the buyer's own copy of this
     * check, written before this method existed and deliberately left where it is - it
     * is a shipped gate on the booking journey and rewriting it to prove a point is a
     * poor trade. SalesConsoleVerificationServiceTest asserts the two agree.
     */
    public static List<String> missingForSend(Account a) {
        List<String> missing = new List<String>();
        if (a == null) {
            return missing;
        }
        if (String.isBlank(a.Nationality__pc))         { missing.add('nationality'); }
        if (String.isBlank(a.UAE_Resident_Status__pc)) { missing.add('residency'); }
        if (String.isBlank(a.PersonEmail))             { missing.add('email address'); }
        if (String.isBlank(a.PersonMobilePhone))       { missing.add('mobile number'); }
        return missing;
    }

    /**
     * THE UNIT THE CUSTOMER IS VERIFYING AGAINST, WRITTEN BEFORE THE SEND.
     *
     * sendKYCForm stamps these three itself - from the SALES ORDER, via
     * getLatestUnitInfo. At step 2 there is no Sales Order, so its lookup returns
     * null and, because its stamping is guarded by `if (so != null)`, it leaves
     * whatever we wrote alone. The customer's KYC form and email therefore name the
     * unit they are actually buying instead of arriving blank.
     *
     * After Confirm, when a Sales Order exists and the rep re-sends from step 4,
     * MODON's own lookup takes over and overwrites these with the authoritative
     * record. That is correct and needs no special handling here.
     *
     * ORDERING IS LOAD-BEARING: this must be committed BEFORE sendKYCForm runs,
     * because the email Flow fires on sendKYCForm's own update. See SendKycLinkJob
     * for why that forces the send into a second transaction.
     *
     * A basket gets its PRIMARY unit only. KYCUnitName__pc is Text(255) and
     * MODON's own getLatestUnitInfo is LIMIT 1, so a single unit is what the rest
     * of the org displays for a multi-unit customer; joining names would diverge
     * from that and risk truncation.
     */
    public static void stampUnitContext(Id opportunityId, Id primaryUnitId) {
        if (opportunityId == null) {
            return;
        }
        Opportunity opp = loadOpportunity(opportunityId);
        stampOnAccount(opp == null ? null : opp.AccountId, primaryUnitId);
    }

    /**
     * 1.4 - THE SAME STAMP, FOR A PARTY WHO IS NOT THE BUYER.
     *
     * A joint owner's Signzy form and email have to name the unit they are co-buying,
     * and their Account is not the Opportunity's - which is the one and only reason
     * the form above could not serve them.
     *
     * WHY THIS ALSO SURVIVES, WHICH IS NOT OBVIOUS. sendKYCForm stamps these three
     * fields itself from getLatestUnitInfo(PersonContactId), whose query is
     * `SalesOrder__c WHERE PrimaryContact__c = :contactId`. A joint owner is not the
     * primary contact on any Sales Order, so that lookup returns null, its
     * `if (so != null)` guard holds, and what we write here is what the customer
     * reads. (If this person is separately a buyer on a booking of their own, MODON's
     * lookup finds THAT unit and wins. That is their behaviour, it is what the buyer
     * path already accepts, and it is not fought here.)
     *
     * A DISTINCT NAME RATHER THAN A THIRD ARGUMENT. The obvious overload,
     * stampUnitContext(Id, Id, Boolean isParty), would be ambiguous with the form
     * above without that boolean, and a flag that must be true at every call site
     * carries no meaning where it is read. Both doors run the one body below, so the
     * buyer's stamp is provably the same code it has always been.
     */
    public static void stampUnitContextForParty(Id accountId, Id primaryUnitId) {
        stampOnAccount(accountId, primaryUnitId);
    }

    /** The one body. See both public forms above for why each exists. */
    private static void stampOnAccount(Id accountId, Id primaryUnitId) {
        if (accountId == null || primaryUnitId == null) {
            return;
        }
        List<Unit__c> units = [
            SELECT Id, Name, Project_Name__c, Phase__r.EntityName__c
            FROM Unit__c
            WHERE Id = :primaryUnitId
            LIMIT 1
        ];
        if (units.isEmpty()) {
            return;
        }
        Unit__c unit = units[0];

        Account acc = new Account(Id = accountId);
        acc.KYCUnitName__pc       = unit.Name;
        acc.KYCProjectName__pc    = unit.Project_Name__c;
        acc.KYCMasterPlanName__pc = unit.Phase__r == null ? null : unit.Phase__r.EntityName__c;

        /* allowSave, matching sendKYCForm's own DML options. A duplicate rule that
           only warns must not stop a field-level stamp on an account that already
           exists. */
        Database.DMLOptions options = new Database.DMLOptions();
        options.DuplicateRuleHeader.allowSave = true;
        Database.update(acc, options);
    }

    /**
     * Hands the Signzy call to a second transaction. See SendKycLinkJob's header for
     * why it cannot run inline.
     */
    public static void enqueueSend(Id accountId) {
        if (accountId == null) {
            return;
        }
        /* Not enqueued under test. The job's only statement is a callout into
           MODON's handler, which would need their whole integration mocked to say
           nothing useful; SendKycLinkJobTest exercises the job directly with a mock
           instead. Guarding here keeps every other test in this class free of the
           one-queueable-per-test limit. */
        if (Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(new SendKycLinkJob(accountId));
    }

    /**
     * THE WAY OUT OF THE GATE.
     *
     * Without this a link that expires, or a customer whose phone is flat, leaves a
     * live booking permanently stuck with a buyer sitting in front of the rep. The
     * field is history-tracked so a booking that proceeded unverified is auditable
     * rather than silent.
     */
    public static void releaseToBranch(Id opportunityId) {
        if (opportunityId == null) {
            return;
        }
        update new Opportunity(
            Id = opportunityId,
            Verification_In_Branch__c = true
        );
        logVerificationFollowUp(opportunityId);
    }

    /**
     * 1.1 - THE FOLLOW-UP, SO A RELEASED BOOKING IS CHASED RATHER THAN FORGOTTEN.
     *
     * The checkbox above records that a booking proceeded unverified. It does not
     * ask anyone to do anything about it, and a flag nobody is looking at is not a
     * control. This raises a Task on the Opportunity - MODON's own place for one,
     * with 1,568 already there under the same record type - owned by the
     * opportunity's owner.
     *
     * THREE THINGS IT DELIBERATELY DOES NOT DO.
     *
     *   IT NEVER BLOCKS THE RELEASE. Database.insert(..., false), and no exception
     *   escapes. This whole method exists because the gate needs a way out that
     *   always works; failing the transaction because a follow-up could not be
     *   written would turn the safety valve into a second way of getting stuck. If
     *   the Task is lost the checkbox survives, and it is history-tracked, so the
     *   audit trail is intact either way.
     *
     *   IT NEVER RAISES A SECOND ONE. A rep who releases, re-arms and releases
     *   again would otherwise leave two open tasks for one obligation. The subject
     *   prefix is the key - it is a constant here, so the guard and the write can
     *   never drift apart.
     *
     *   IT DOES NOT NAME A BRANCH. The button the rep pressed says "continue and
     *   verify later" and says nothing about where; the subject matches, so a task
     *   list does not assert a process that may not be MODON's.
     */
    @TestVisible
    private static final String FOLLOW_UP_SUBJECT = 'Complete identity verification';

    private static void logVerificationFollowUp(Id opportunityId) {
        try {
            List<Opportunity> opps = [
                SELECT Id, Name, OwnerId, AccountId, Account.Name,
                       Account.IsPersonAccount, Account.PersonContactId
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            if (opps.isEmpty() || opps[0].OwnerId == null) {
                return;
            }
            Opportunity opp = opps[0];

            String subjectKey = FOLLOW_UP_SUBJECT + '%';
            List<Task> open = [
                SELECT Id
                FROM Task
                WHERE WhatId = :opportunityId
                  AND IsClosed = false
                  AND Subject LIKE :subjectKey
                LIMIT 1
            ];
            if (!open.isEmpty()) {
                return;
            }

            String customer = opp.Account == null ? null : opp.Account.Name;
            Task t = new Task(
                OwnerId      = opp.OwnerId,
                WhatId       = opp.Id,
                Subject      = FOLLOW_UP_SUBJECT
                                 + (String.isBlank(customer) ? '' : ' - ' + customer),
                /* Two days, not today: the rep is mid-booking with the customer in
                   front of them, and a task due this minute is one they will close
                   unread to clear the badge. */
                ActivityDate = Date.today().addDays(2),
                Status       = 'Open',
                Priority     = 'High',
                Description  =
                    'This booking continued before the customer completed their '
                    + 'identity verification (KYC).\n\n'
                    + 'Opportunity: ' + opp.Name + '\n'
                    + 'Customer: ' + (String.isBlank(customer) ? '(not named)' : customer) + '\n\n'
                    + 'Complete the identity check with the customer and confirm '
                    + 'KYC on the account. Raised automatically by the Sales '
                    + 'Console when the verification gate was released.'
            );
            /* Person accounts only. On a company account PersonContactId is null,
               and a Task with no WhoId is valid - it just does not appear on a
               contact's timeline, because there is no contact. */
            if (opp.Account != null && opp.Account.IsPersonAccount == true) {
                t.WhoId = opp.Account.PersonContactId;
            }
            Id rtId = followUpRecordTypeId();
            if (rtId != null) {
                t.RecordTypeId = rtId;
            }
            Database.insert(t, false);
        } catch (Exception e) {
            /* Swallowed on purpose - see the header. The release has already
               committed and must stand. */
            System.debug(LoggingLevel.WARN,
                'SalesConsoleVerificationService: follow-up task not raised for '
                + opportunityId + ' - ' + e.getMessage());
        }
    }

    /**
     * The record type MODON's own opportunity tasks already use, so this lands in
     * the same list views and page layouts rather than beside them. Null when the
     * running user has no access to it, in which case the Task is written with the
     * default - a task on the wrong layout still beats no task.
     */
    private static Id followUpRecordTypeId() {
        Schema.RecordTypeInfo info = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('Opportunity');
        return (info != null && info.isAvailable()) ? info.getRecordTypeId() : null;
    }

    /** Undo, for a rep who released by mistake and the customer is verifying after all. */
    public static void rearmGate(Id opportunityId) {
        if (opportunityId == null) {
            return;
        }
        update new Opportunity(
            Id = opportunityId,
            Verification_In_Branch__c = false
        );
    }
}