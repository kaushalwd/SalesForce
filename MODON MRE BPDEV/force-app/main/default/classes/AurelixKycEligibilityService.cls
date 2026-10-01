/**
 * AurelixKycEligibilityService - one KYC verdict for the Sales Console.
 *
 * Version  Author       Date         Detail
 * 2.9      Aurelix Dev  29 Sep 2026  No POA pre-check for a company's own booking: its primary contact is
 *                                    the POA (MODON confirmed), so the verdict is MODON's checkKYCEligibility
 *                                    alone. resolveAuthorisedPoaContact is removed.
 * 2.8      Aurelix Dev  27 Sep 2026  A COMPANY'S VERDICT IS MODON'S TOO (27 Sep: the console must behave
 *                                    as MODON's Sales App does). Since checkKYCEligibility 18.1 (24 Sep) MODON
 *                                    reads a company's KYC, nationality, residency and documents from the
 *                                    opportunity's primary contact, so the reason below for not delegating
 *                                    ("WHY PERSON DELEGATES AND ORGANISATION DOES NOT") no longer holds.
 *                                    evaluateOrganisation keeps its Power of Attorney pre-check (the POA row
 *                                    must exist and be the primary contact; on hold pending a
 *                                    recheck with MODON) and then takes MODON's answer word for word, as
 *                                    evaluatePerson does (applyModonVerdict): the first failure only, in
 *                                    MODON's sentences, where 2.7 listed every reason in its own. Measured
 *                                    read-only on the 85 open company opportunities in DEV: no verdict
 *                                    changes. The documents list is still worked out here for the screen,
 *                                    only when MODON's refusal is the documents one, and the company half is
 *                                    now looked for on the primary contact's account, where MODON looks.
 * 2.7      Aurelix Dev  27 Sep 2026  MODON's Check 2A on the organisation path.
 *                                    UnitSearchLwcController.checkKYCEligibility (v18.1) refuses any
 *                                    booking whose PrimaryContact__r.Nationality__c is blank, after the
 *                                    KYC check and before residency ("Nationality is not set on the
 *                                    Primary Contact. Please populate it before booking."). Person buyers
 *                                    already get it by delegation; the organisation branch did not ask.
 *                                    It now does, on the authorised signatory, who is the Primary
 *                                    Contact by this point, in the residency line's wording. In DEV,
 *                                    13 of 85 open company opportunities have a primary contact with no
 *                                    nationality, so the payment guard will name it for them.
 * 2.6      Aurelix Dev  27 Sep 2026  A COMPANY IS APPROVED ON ITS POA CONTACT ONLY (27 Sep,
 *                                    after MODON's answer of 26 Sep: "For the company, we will
 *                                    check the KYC status on the Primary Contact"). The 2.4
 *                                    fallback to Account.Manual_KYC_Approval__c on the company is
 *                                    removed, with firstApproved. MODON's own checkKYCEligibility
 *                                    18.1 already reads only PrimaryContact__r for a company, so an
 *                                    approval left on a company account from before 21 Sep no
 *                                    longer opened MODON's gate but still opened ours. Such a
 *                                    company now needs a new approval on its POA Contact. In DEV
 *                                    on 27 Sep this affected one company, whose POA has neither an
 *                                    approval nor a valid KYC. The person route is unchanged.
 * 2.5      Aurelix Dev  24 Sep 2026  The authorised POA Contact's KYC status is now MODON's own
 *                                    Contact.KYC_Status__c formula, which MODON
 *                                    created on 23 Sep 2026. Our three month validity constant
 *                                    and the helper that derived a status from a completion date
 *                                    are deleted: this class copies no rule of MODON's any more.
 *                                    The manual approval condition is untouched and still decides
 *                                    what their formula cannot. Their formula ignores
 *                                    Contact.Manual_KYC_Approval__c, so a signatory approved by
 *                                    hand has no completion date and reads 'KYC not complete' on
 *                                    their own record, yet is still accepted here. Needs
 *                                    Contact.KYC_Status__c to exist in the target org.
 * 2.4      Aurelix Dev  23 Sep 2026  A company's manual KYC can now sit on its Power of Attorney.
 *                                    MODON added a Contact level manual KYC on 21 Sep and
 *                                    confirmed on 22 Sep that it is for the POA. Option 2 accepts an
 *                                    approval on the POA Contact as well as on the company Account,
 *                                    since companies approved before that change carry it there.
 * 2.3      Aurelix Dev  18 Sep 2026  MSC-176 (B6) / MSC-182 (B10). Two blocker sentences no longer
 *                                    say "Opportunity" (the record is never exposed to a rep).
 *                                    resolveAuthorisedPoaContact now delegates to
 *                                    AurelixPoaResolver - the same rule, held once, so manual KYC
 *                                    and the document checklist name the same signatory as the
 *                                    verdict. Behaviour unchanged; the @TestVisible wrapper stays
 *                                    so the existing tests still pin it.
 * 2.2      Aurelix Dev  08 Sep 2026  BUYER-TYPE ROUTING FIX. The buyer type is now taken from
 *                                    the COMMERCIAL BUYER - Opportunity.Account - and from nothing
 *                                    else. Two defects are closed:
 *                                      1 A null PrimaryContact__c returned 'Person' and read the
 *                                        PERSON switch BEFORE the account was ever looked at, so a
 *                                        company with no contact yet was governed by the wrong
 *                                        gate. Forensic evidence: five SalesConsoleControllerTest
 *                                        fixtures build an Organization Account and were being
 *                                        enforced as persons.
 *                                      2 Classification read PrimaryContact__r.Account, letting the
 *                                        CONTACT redefine the commercial buyer type.
 *                                    Account.IsPersonAccount decides, because it is Salesforce's
 *                                    own answer and is never blank - 31 opportunities in
 *                                    MODON_DEV_1 carry an account whose record type NAME is null.
 *                                    The primary contact is the human SUBJECT of the check and is
 *                                    validated only after the buyer type and its switch are known.
 *                                    Organisation Option 2 is unchanged apart from companyId now
 *                                    being Opportunity.AccountId.
 * 2.1      Aurelix Dev  08 Sep 2026  SC-UI-007. KycStateDTO.hasAuthorisedPoa reports whether a
 *                                    Power of Attorney was actually resolved. Reporting only -
 *                                    POA resolution itself is untouched.
 * 2.0      Aurelix Dev  07 Sep 2026  Phase 4. isEnforcementOn() for the fail-closed money guard.
 * 1.0      Aurelix Dev  07 Sep 2026  Phase 1. Person buyers delegate to MODON's own rule;
 *                                    organisation buyers are evaluated by Option 2 (the
 *                                    authorised POA Contact is the human KYC subject).
 *                                    Read-only. Enforcement is OFF - see isHardGateActive.
 *
 * OWNERSHIP. This class is Aurelix-owned. Everything it reaches into is MODON's and is
 * CALLED, never modified:
 *   UnitSearchLwcController.checkKYCEligibility  the person rule, in full
 *   Account.KYC_Status__c, Contact.KYC_Status__c the KYC status itself, read as published
 *   Documents__c                                 document evidence (2.9: Power_of_Attorney__c is no longer read)
 *
 * WHY PERSON DELEGATES AND ORGANISATION DOES NOT. (Superseded by 2.8: both delegate now.)
 * MODON's gate reads PrimaryContact__r.Account.KYC_Status__c. For a person buyer that is the
 * buyer's own account and the rule is complete, so we call it and translate the answer.
 * For an organisation buyer that same field is the COMPANY's, and the company never completes
 * a Signzy journey - the authorised POA Contact does. Measured in DEV_1 on 07 Sep 2026:
 * 6 of 9 POA contacts hold real completion dates going back to April 2026, while all 56
 * organisation accounts read 'KYC not complete'. Delegating organisations would therefore
 * block every corporate booking, including genuinely verified customers. Option 2 reads the
 * records that actually carry the evidence.
 *
 * WHERE THE STATUS COMES FROM. NOT FROM HERE.
 * Both paths read MODON's own formula. Account.KYC_Status__c answers for a person buyer, and
 * Contact.KYC_Status__c, which MODON created on 23 Sep 2026, answers for the authorised POA
 * Contact. The two formulas are the same text once whitespace is ignored:
 *   IF(ISBLANK(KYC_Completed_Date__c), "KYC not complete",
 *      IF(ADDMONTHS(KYC_Completed_Date__c, 3) < TODAY(), "KYC Expired", "KYC Active"))
 * Until 2.5 this class held its own three month constant, because Contact carried the completion
 * date and no formula to judge it. That is no longer true, so the constant and the helper that
 * used it are gone and no validity rule of MODON's is duplicated here.
 * Drift control: AurelixKycEligibilityServiceTest reads Contact.KYC_Status__c back from the org
 * for a recent, an old and a blank completion date, and cross checks it against the Account
 * formula, so a change to MODON's period, or the two fields falling out of step, fails our build
 * instead of the console quietly disagreeing with the record page.
 * The one thing their formula does not publish is the date a status will flip. That is
 * dto.validUntil, derived below for display only and pinned by the same test.
 *
 * MANUAL APPROVAL IS A SEPARATE ROUTE, AND IT HAS TO STAY.
 * MODON's formula reads only KYC_Completed_Date__c, so it ignores Manual_KYC_Approval__c
 * completely. A POA approved by hand has no completion date and therefore reads 'KYC not
 * complete'. Option 2 accepts a valid status OR a manual approval on the POA Contact. Folding the
 * status question into their formula alone would block every manually approved company.
 *
 * RELEASE DEPENDENCY.
 * Contact.KYC_Status__c exists in MODON_DEV_1 only. This class does not compile in an org that
 * lacks it, so it travels with the Sales Console release.
 */
public with sharing class AurelixKycEligibilityService {

    /* Kept for documentation and diagnostics: from 2.2 the decision is IsPersonAccount. */
    private static final String RT_ORGANISATION = 'Organization Account';

    /* 2.2 - a buyer we cannot classify. Never silently treated as either type. */
    @TestVisible
    private static final String CUSTOMER_UNKNOWN = 'Unknown';

    /* KYC_Status__c formula outputs, verbatim. 'KYC Expired' is the third one and is no longer
       named here: from 2.5 an expired status arrives from MODON's field, never from our own
       arithmetic, so a constant for it would be dead. */
    private static final String STATUS_NOT_COMPLETE = 'KYC not complete';

    /* Documents__c.Name values, matching UnitSearchLwcController v14.2 exactly. */
    private static final String DOC_SIGNED_KYC = 'KYC Form - Signed';
    private static final String DOC_PASSPORT   = 'Passport';
    private static final String DOC_EID_FRONT  = 'Emirates/National ID Front';
    private static final String DOC_EID_BACK   = 'Emirates/National ID Back';
    private static final String DOC_TRADE_LIC  = 'Commercial trade License (Resident)';
    private static final String DOC_CERT_INC   = 'Certificate of Incorporation (Non Resident)';

    /* Feature switches. Both false after Phase 1 - nothing may be blocked. */
    public static final String FLAG_PERSON = 'PERSON_KYC_HARD_GATE';
    public static final String FLAG_ORG    = 'ORGANISATION_KYC_HARD_GATE';

    /** What the console needs to render a KYC panel and, later, to gate money. */
    public class KycStateDTO {
        @AuraEnabled public Boolean eligible = false;
        @AuraEnabled public String  blockedReason;
        @AuraEnabled public List<String> missingDocuments = new List<String>();
        @AuraEnabled public String  kycStatus;
        @AuraEnabled public Date    completedDate;
        @AuraEnabled public Date    validUntil;
        /** 'Person' or 'Organisation'. */
        @AuraEnabled public String  customerType;
        /** The human who must verify. Id + display name only - no documents, DOB or contact details. */
        @AuraEnabled public Id      primaryContactId;
        @AuraEnabled public String  primaryContactName;
        @AuraEnabled public String  manualApprovalStatus;
        /** NOT_SENT | ACTIVE | INACTIVE. Derived from KYC_Send_Date_Time__c, never from
         *  Send_KYC_Verification_Email__c, which MODON's Flow clears on send. */
        @AuraEnabled public String   linkState;
        @AuraEnabled public Datetime linkSentAt;
        @AuraEnabled public Datetime linkExpiresAt;
        /** True when the hard gate is switched on for this customer type. Phase 1: always false. */
        @AuraEnabled public Boolean enforcementActive = false;
        /**
         * 2.1 - SC-UI-007. Whether a company booking has its Power of Attorney. 2.9: true whenever
         * the company booking has a primary contact (that contact is the POA). c/mscKycGate names them
         * "POA" on this flag. False for a person buyer, and for a company with no primary contact yet.
         */
        @AuraEnabled public Boolean hasAuthorisedPoa = false;
    }

    /**
     * The one entry point. Read-only - no DML anywhere in this class or anything it calls.
     * Never throws for business reasons: an unusable input returns a blocked DTO with a reason.
     */
    @AuraEnabled
    public static KycStateDTO evaluate(Id opportunityId) {
        KycStateDTO dto = new KycStateDTO();

        if (opportunityId == null) {
            dto.blockedReason = 'No opportunity to evaluate.';
            return dto;
        }

        List<Opportunity> opps = [
            SELECT Id, AccountId,
                   /* 2.2 - the COMMERCIAL BUYER. Classification reads these and nothing else. */
                   Account.IsPersonAccount,
                   Account.RecordType.Name,
                   PrimaryContact__c,
                   PrimaryContact__r.Name,
                   PrimaryContact__r.AccountId,
                   PrimaryContact__r.Account.RecordType.Name,
                   PrimaryContact__r.Account.Manual_KYC_Approval__c,
                   PrimaryContact__r.Account.KYC_Status__c,
                   /* 2.4 - the POA's own manual approval (MODON's Contact process, 21 Sep) */
                   PrimaryContact__r.Manual_KYC_Approval__c,
                   /* 2.5 - MODON's own status formula on the POA Contact, created 23 Sep 2026.
                      This IS the organisation path's status; nothing here computes one. */
                   PrimaryContact__r.KYC_Status__c,
                   PrimaryContact__r.KYC_Completed_Date__c,
                   PrimaryContact__r.UAE_Resident_Status__c,
                   /* 2.7 - MODON's Check 2A */
                   PrimaryContact__r.Nationality__c,
                   PrimaryContact__r.KYC_Send_Date_Time__c,
                   PrimaryContact__r.KYC_Link_Expiry_At__c,
                   PrimaryContact__r.Is_KYC_Link_Active__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            /* 2.2 - we cannot know the buyer type, so we cannot know which switch governs.
               Fail closed while ANY gate is on rather than silently disable enforcement. */
            dto.blockedReason     = 'Booking not found.';
            dto.kycStatus         = STATUS_NOT_COMPLETE;
            dto.enforcementActive = isEnforcementOn();
            return dto;
        }
        Opportunity opp = opps[0];

        /* ── 2.2 STEP 1: the buyer is Opportunity.Account, and only that ─────────────
           No commercial buyer at all means no knowable switch. Picking one would be a guess,
           and guessing 'Person' is precisely the defect this version closes. */
        if (opp.AccountId == null) {
            dto.customerType      = CUSTOMER_UNKNOWN;
            dto.kycStatus         = STATUS_NOT_COMPLETE;
            dto.blockedReason     = 'No customer account is set on this booking. '
                                  + 'Set the customer before booking.';
            dto.enforcementActive = isEnforcementOn();
            return dto;
        }

        /* ── STEP 2: buyer type. IsPersonAccount is Salesforce's own answer and is never
           blank; the record type NAME is not (31 opportunities in MODON_DEV_1 carry an
           account with a null record type). Anything that is not a person account is a
           company, whatever its record type is called. 2.9: its subject is the primary contact,
           who is the POA, as MODON reads it. */
        Boolean isOrganisation = (opp.Account.IsPersonAccount != true);
        dto.customerType = isOrganisation ? 'Organisation' : 'Person';

        /* ── STEP 3: the switch follows the buyer type, decided before any subject check. */
        dto.enforcementActive = isHardGateActive(isOrganisation ? FLAG_ORG : FLAG_PERSON);

        /* The manual route belongs to the account being assessed: the company for an
           organisation, and - mirroring MODON's own person rule - the primary contact's
           account for a person. */
        /* 2.6 - a company is approved on its POA Contact (MODON's Contact process) and only
           there. An approval left on the company Account is not read, as in MODON's own gate. */
        dto.manualApprovalStatus = isOrganisation
            ? (opp.PrimaryContact__c == null ? null : opp.PrimaryContact__r.Manual_KYC_Approval__c)
            : (opp.PrimaryContact__c == null
                   ? null
                   : opp.PrimaryContact__r.Account.Manual_KYC_Approval__c);

        /* ── STEP 4: only now is the human SUBJECT of the check validated. A missing subject
           is a blocked verdict, never a change of buyer type. */
        if (opp.PrimaryContact__c == null) {
            dto.kycStatus = STATUS_NOT_COMPLETE;
            if (isOrganisation) {
                /* 2.9 - MODON's own refusal, word for word (its Check 1). No POA row is looked for. */
                applyModonVerdict(opp, dto);
            } else {
                dto.blockedReason = 'No customer is attached to this booking. '
                                  + 'Please add a Primary Contact and complete KYC before booking.';
            }
            return dto;
        }

        dto.primaryContactId   = opp.PrimaryContact__c;
        dto.primaryContactName = opp.PrimaryContact__r.Name;

        /* ── STEP 5: the buyer-type rule runs. */
        if (isOrganisation) {
            evaluateOrganisation(opp, dto);
        } else {
            evaluatePerson(opp, dto);
        }
        return dto;
    }

    /**
     * PERSON. MODON's rule, in full, unmodified. We add nothing and subtract nothing - we
     * translate its {blocked, message} into the console's shape.
     */
    private static void evaluatePerson(Opportunity opp, KycStateDTO dto) {
        applyModonVerdict(opp, dto);
        dto.kycStatus     = opp.PrimaryContact__r.Account.KYC_Status__c;

        /* Dates are for display only; the verdict above is MODON's, not ours. */
        Date completed = personCompletedDate(opp.PrimaryContact__r.AccountId);
        dto.completedDate = completed;
        dto.validUntil    = validUntil(completed);

        applyLinkState(dto,
            opp.PrimaryContact__r.KYC_Send_Date_Time__c,
            opp.PrimaryContact__r.KYC_Link_Expiry_At__c,
            opp.PrimaryContact__r.Is_KYC_Link_Active__c);
    }

    /**
     * ORGANISATION. 2.9: MODON's checkKYCEligibility on the primary contact, who is the company's POA;
     * no Power_of_Attorney__c row is needed. Status, dates and link state are for the screen only.
     */
    private static void evaluateOrganisation(Opportunity opp, KycStateDTO dto) {
        /* 2.9 - the primary contact is the POA; nothing is resolved from Power_of_Attorney__c. */
        dto.hasAuthorisedPoa = true;

        Date completed = opp.PrimaryContact__r.KYC_Completed_Date__c;
        dto.completedDate = completed;
        dto.validUntil    = validUntil(completed);
        /* 2.5 - MODON's formula field, reported as published. A formula always returns one of its
           three strings, so the blank guard covers only a field we could not read at all, and it
           fails in the safe direction: anything that is not 'KYC Active' needs the manual route. */
        dto.kycStatus     = String.isBlank(opp.PrimaryContact__r.KYC_Status__c)
                            ? STATUS_NOT_COMPLETE
                            : opp.PrimaryContact__r.KYC_Status__c;

        applyLinkState(dto,
            opp.PrimaryContact__r.KYC_Send_Date_Time__c,
            opp.PrimaryContact__r.KYC_Link_Expiry_At__c,
            opp.PrimaryContact__r.Is_KYC_Link_Active__c);

        /* 2.8 - the verdict is MODON's, exactly as for a person */
        applyModonVerdict(opp, dto);

        /* the documents view, only where MODON's first failure is the documents one */
        if (dto.eligible != true && dto.blockedReason != null
                && dto.blockedReason.startsWith(MODON_DOCUMENTS_REFUSAL)) {
            dto.missingDocuments.addAll(missingDocumentsFor(
                opp.PrimaryContact__c, opp.PrimaryContact__r.AccountId, opp.PrimaryContact__r.UAE_Resident_Status__c));
        }
    }

    /** 2.8 - how MODON's documents refusal begins (checkKYCEligibility 18.1). */
    @TestVisible
    private static final String MODON_DOCUMENTS_REFUSAL = 'KYC documents are incomplete';

    /** 2.8 - MODON's checkKYCEligibility, its answer kept word for word. Both buyer types. */
    private static void applyModonVerdict(Opportunity opp, KycStateDTO dto) {
        UnitSearchLwcController.KYCEligibilityResult r =
            UnitSearchLwcController.checkKYCEligibility(String.valueOf(opp.Id));
        dto.eligible      = (r != null && r.blocked != true);
        dto.blockedReason = dto.eligible ? null : (r == null ? 'Eligibility could not be evaluated.' : r.message);
    }

    /**
     * 2.8 - the documents MODON's check names, for the screen's checklist: on the contact, the signed
     * KYC form and the passport, and for a Resident both Emirates ID sides; on the contact's account,
     * one of the trade licence or the certificate of incorporation. The file test is MODON's too
     * (a ContentDocumentLink, or a classic Attachment), read without sharing.
     */
    private static List<String> missingDocumentsFor(Id contactId, Id companyId, String residency) {
        List<String> missing = new List<String>();
        List<String> requiredOnContact = new List<String>{ DOC_SIGNED_KYC, DOC_PASSPORT };
        if (String.isNotBlank(residency) && residency.trim().equalsIgnoreCase('Resident')) {
            requiredOnContact.add(DOC_EID_FRONT);
            requiredOnContact.add(DOC_EID_BACK);
        }
        List<String> acceptedOnCompany = new List<String>{ DOC_TRADE_LIC, DOC_CERT_INC };

        Map<String, Set<Id>> contactDocs = new Map<String, Set<Id>>();
        Set<Id> companyDocIds = new Set<Id>();
        Set<Id> allDocIds = new Set<Id>();
        for (Documents__c d : [
            SELECT Id, Name FROM Documents__c
            WHERE PrimaryContact__c = :contactId AND Name IN :requiredOnContact
        ]) {
            if (!contactDocs.containsKey(d.Name)) { contactDocs.put(d.Name, new Set<Id>()); }
            contactDocs.get(d.Name).add(d.Id);
            allDocIds.add(d.Id);
        }
        if (companyId != null) {
            for (Documents__c d : [
                SELECT Id, Name FROM Documents__c
                WHERE Account__c = :companyId AND Name IN :acceptedOnCompany
            ]) {
                companyDocIds.add(d.Id);
                allDocIds.add(d.Id);
            }
        }
        Set<Id> withFile = new FileContext().parentsWithFiles(allDocIds);

        for (String docName : requiredOnContact) {
            Boolean satisfied = false;
            if (contactDocs.containsKey(docName)) {
                for (Id docId : contactDocs.get(docName)) {
                    if (withFile.contains(docId)) { satisfied = true; break; }
                }
            }
            if (!satisfied) { missing.add(docName); }
        }
        Boolean companySatisfied = false;
        for (Id docId : companyDocIds) {
            if (withFile.contains(docId)) { companySatisfied = true; break; }
        }
        if (!companySatisfied) {
            missing.add('one of ' + String.join(acceptedOnCompany, ' or ') + ' on the company');
        }
        return missing;
    }

    /* 2.9 - resolveAuthorisedPoaContact is removed: the verdict no longer reads Power_of_Attorney__c. */

    /** Latest completion date on the buyer's own account, for display. */
    private static Date personCompletedDate(Id accountId) {
        if (accountId == null) { return null; }
        List<Account> a = [SELECT KYC_Completed_Date__c FROM Account WHERE Id = :accountId LIMIT 1];
        return a.isEmpty() ? null : a[0].KYC_Completed_Date__c;
    }

    /**
     * DISPLAY ONLY - the date on which MODON's KYC_Status__c will flip a record to 'KYC Expired'.
     *
     * 2.5: this decides nothing. The verdict on both paths is MODON's formula field. This is the
     * single thing that formula does not publish, and the console renders it, so it is read
     * straight off their ADDMONTHS(KYC_Completed_Date__c, 3) rather than kept as a rule of ours.
     * AurelixKycEligibilityServiceTest pins it to the live Contact field, so if MODON ever
     * changes the period this build fails. Null in, null out.
     */
    @TestVisible
    private static Date validUntil(Date completed) {
        return completed == null ? null : completed.addMonths(3);
    }

    private static void applyLinkState(KycStateDTO dto, Datetime sentAt, Datetime expiresAt, Boolean active) {
        dto.linkSentAt    = sentAt;
        dto.linkExpiresAt = expiresAt;
        dto.linkState     = (sentAt == null) ? 'NOT_SENT' : (active == true ? 'ACTIVE' : 'INACTIVE');
    }

    /**
     * Is the hard gate switched on for this customer type? Read from custom metadata so it can be
     * turned off in Setup without a deployment. Absent record means OFF - the safe default, and
     * the state Phase 1 ships in.
     */
    /**
     * 2.0 - Phase 4. Is ANY hard gate switched on?
     *
     * Exists for one purpose: the money guard in SalesConsoleController must FAIL CLOSED. If
     * evaluate() itself throws, there is no DTO to read enforcementActive from, and the caller
     * still has to decide whether to refuse. When no gate is on, an evaluation failure must
     * change nothing (Phase 1-3 behaviour is preserved exactly); when a gate IS on, an
     * unverifiable customer must not be treated as verified.
     */
    public static Boolean isEnforcementOn() {
        return isHardGateActive(FLAG_PERSON) || isHardGateActive(FLAG_ORG);
    }

    @TestVisible
    private static Boolean isHardGateActive(String developerName) {
        /* No Test.isRunningTest() short-circuit on purpose: custom metadata is readable in tests,
           so the tests assert the REAL deployed switch values rather than a hardcoded false. */
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(developerName);
        return cfg != null && cfg.Is_Active__c == true;
    }

    /**
     * File presence without sharing, so a required document still counts when somebody else
     * uploaded it. This mirrors the posture of MODON's own KYCFileContext deliberately: if we ran
     * this with sharing, a correctly documented customer would be reported as missing evidence.
     * Read-only.
     */
    private without sharing class FileContext {
        public Set<Id> parentsWithFiles(Set<Id> parentIds) {
            Set<Id> withFile = new Set<Id>();
            if (parentIds == null || parentIds.isEmpty()) { return withFile; }
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :parentIds
            ]) {
                withFile.add(cdl.LinkedEntityId);
            }
            Set<Id> remaining = new Set<Id>(parentIds);
            remaining.removeAll(withFile);
            if (!remaining.isEmpty()) {
                for (Attachment att : [SELECT ParentId FROM Attachment WHERE ParentId IN :remaining]) {
                    withFile.add(att.ParentId);
                }
            }
            return withFile;
        }
    }
}