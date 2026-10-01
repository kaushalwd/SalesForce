/**
 * The compliance check the rep runs before submitting a customer.
 *
 * Version  Author      Date         Detail
 * 1.x+4    Aurelix Dev  29 Sep 2026  partyAccounts reads Manual_KYC_Approval__c, so a joint owner
 *                                    approved by manual KYC passes the check (isManuallyApproved
 *                                    was always false for a party).
 * 1.x+3    Aurelix Dev  28 Sep 2026  FieldDTO.required (testing, 28 Sep): true for every field
 *                                    the submit waits on (each detail in a section, and the two
 *                                    required booking-context choices), so the panel can mark them
 *                                    and take the rep to the one still missing. Additive only: no
 *                                    rule, count, gate or sentence changes.
 * 1.x+2    Aurelix Dev  27 Sep 2026  A company's manual KYC approval is read from its Power of
 *                                    Attorney Contact only (27 Sep, after MODON's answer
 *                                    of 26 Sep), as MODON's own checkKYCEligibility 18.1 does. The
 *                                    signatory path used to read the company Account's approval,
 *                                    which MODON no longer counts. The person path is unchanged.
 * 1.x+1    Aurelix Dev  18 Sep 2026  On the manual route the "verified" fields (occupation, employer,
 *                                    purpose, contact details, address) are offered for typing and
 *                                    accepted on save: Signzy never ran, so the rep supplies them.
 * 1.x      Aurelix Dev  18 Sep 2026  Compliance may follow a MANUAL KYC approval (buyer: the Account;
 *                                    company: the company Account) - the two "has not finished
 *                                    identity verification" gates no longer demand a completion date.
 * 3.1      Aurelix Dev 30 Aug 2026  MSC-181. Wording only: the corporate blocked
 *                                   sentence names the role 'Power of Attorney' and
 *                                   says 'assigned', matching SalesConsoleOrgController
 *                                   2.0. No gate, no value and no path changes.
 * 1.0      Aurelix IT  19 Aug 2026  Initial. MSC-069.
 * 1.1      Aurelix IT  19 Aug 2026  Identity Proof suggested from residency. MSC-070.
 * 1.2      Aurelix IT  19 Aug 2026  Verified details are read only. MSC-071.
 * 1.3      Aurelix IT  19 Aug 2026  One details section. MSC-072.
 * 1.4      Aurelix IT  19 Aug 2026  Email and Mobile are read only too. MSC-073.
 * 1.5      Aurelix IT  19 Aug 2026  Identity Proof is derived and read only; the
 *                                   verified details read in a deliberate order. MSC-074.
 * 1.6      Aurelix IT  19 Aug 2026  The property count is derived from MODON's own
 *                                   method rather than a second copy of it. MSC-075.
 * 1.7      Aurelix IT  19 Aug 2026  Booking context is no longer pre-filled. MSC-075.
 * 1.8      Aurelix IT  19 Aug 2026  When the verification finished, to the minute. MSC-076.
 * 1.9      Aurelix IT  19 Aug 2026  Delivery Channel and Payment method hold the
 *                                   submit until the rep chooses them. MSC-077.
 * 1.10     Aurelix IT  19 Aug 2026  The real-beneficiary declaration. MSC-078.
 * 1.11     Aurelix IT  20 Aug 2026  Two field labels read as questions on a form
 *                                   rather than as column headings. MSC-079.
 * 2.0      Aurelix IT  20 Aug 2026  Compliance per person. MSC-083.
 * 3.0      Aurelix Dev 22 Aug 2026  MSC-116. COMPLIANCE HAS THREE SUBJECTS, NOT ONE.
 *                                   This class was contact-centric from its first line
 *                                   and person-account-shaped in every constant. An
 *                                   organisation booking has two subjects it must serve
 *                                   - the COMPANY and its AUTHORISED SIGNATORY - and
 *                                   they are not the buyer with different fields: they
 *                                   read different records, different twins of the same
 *                                   columns, different document keys and different
 *                                   Passfort entity types. So the hardcoded constants
 *                                   became per-entity lookups behind one EntityKind, and
 *                                   the individual path is byte-for-byte what shipped.
 *                                   The signatory can now be checked, corrected and
 *                                   submitted from the console. THE COMPANY CANNOT BE
 *                                   SUBMITTED YET, deliberately: Account_Field_Validation__mdt
 *                                   publishes no active organisation rules, so there is
 *                                   nothing to check it against, and a submission that
 *                                   asserts nothing is worse than none. It renders what
 *                                   is true - its documents, its verdict - and says so.
 *                                   Three hardenings ride along, all of which protect
 *                                   the INDIVIDUAL path too: requiredMeta now reads both
 *                                   record-type columns (the one organisation row carries
 *                                   its discriminator in the column this class never
 *                                   read, so the day MODON activates it, it would have
 *                                   landed on every individual's checklist); an empty
 *                                   requirement set is refused instead of reading as
 *                                   ready to submit; and already-submitted is asked per
 *                                   entity, because a Primary Contact submission is not
 *                                   an 'Individual' one and counting the wrong type is
 *                                   how a panel offers the same submission for ever.
 * 2.1      Aurelix IT  20 Aug 2026  filesPresent is public - the booking detail asks
 *                                   the same question about the same object. MSC-086.
 *
 * ONE PARTY AT A TIME, AND THE PARTY IS AN ARGUMENT.
 *
 * The class was contact-centric from the first line - Ctx.contactId drives the checklist,
 * the documents, the allowlist and the submission - and the only thing that was ever
 * per-booking was WHO that contact belonged to. So 2.0 adds a parameter, not a second
 * implementation: partyAccountId null is the buyer and is the same code that has always
 * run, and partyAccountId set is a joint owner on this booking. Everything below resolve
 * is untouched.
 *
 * THE GUARD IS THE PHASE. A party Id arrives from a browser, so before that Account is
 * read at all it must be proved to be a joint owner on a LIVE Sales Order of THIS
 * Opportunity. Without that check a crafted payload turns this panel into a read of any
 * Account in the org, and a submission for anybody in it. It is the first thing resolve
 * does with a party and there is no path around it.
 *
 * ONE SUBMISSION PER PERSON, NEVER ONE WITH N ENTITIES.
 * createPassfortTransactionRecords opens with deleteDocumentPlaceholders(recordId), keyed
 * to a single contact - so an N-entity payload would clean one person's placeholder
 * documents and send everybody else's blanks to Passfort.
 *
 * THE OLD SIGNATURES SURVIVE, UNANNOTATED. Apex refuses two methods of one name that both
 * carry @AuraEnabled, so the party signature is the exposed one and the original delegates
 * to it with null. SalesConsoleComplianceServiceTest calls the originals and needed no
 * edit at all, which is the proof that the buyer's path did not move.
 *
 * MSC-068 switched automatic submission off, so nothing sends a customer to compliance
 * any more. This is the replacement: the rep opens a check on the Verification step,
 * sees what compliance is still missing, fills it in, and submits deliberately.
 *
 * THE RULES ARE READ, NEVER COPIED. Which fields compliance wants comes from
 * Account_Field_Validation__mdt and which documents from the AutoCompliance* Custom
 * Labels - the same two sources AutoPassfortComplianceService reads. A change to either
 * moves this and the automation together, and there is no second list to drift.
 *
 * VERIFIED DETAILS ARE NOT THE REP'S TO CHANGE. Most of what compliance asks for is
 * written onto the customer by the identity verification itself, and the rep must not be
 * able to overwrite a verified value with a typed one. Those fields are reported as read
 * only and, more to the point, are removed from the save allowlist - so a payload naming
 * one writes nothing even if it never came from this panel.
 *
 * WHAT IT DOES NOT DO. It never opens, names or links a document: getChecklist reports a
 * required document as received or not received and nothing else, so a KYC file the
 * customer uploaded cannot reach the rep through this class. It never writes a field
 * compliance did not ask for - saveDetails works off an allowlist built from the same
 * metadata. And it never decides anything on the client's word: submit() re-runs every
 * check server-side before it acts.
 */
public with sharing class SalesConsoleComplianceService {

    private static final String CLASS_NAME  = 'SalesConsoleComplianceService';
    private static final String PROCESS     = 'Manual Compliance Submission';
    /**
     * 2.0 - a joint owner's submission logs under its own name, and that is load-bearing.
     *
     * SalesConsoleController.applyLastComplianceAttempt reads the newest Logger__c on the
     * Sales Order filtered ONLY by ExecutingProcessName__c IN (the automation's, PROCESS).
     * A joint owner's submission lands on the same order, so under the same name it would
     * surface on the buyer's compliance card as the BUYER's last attempt - a sentence
     * about the wrong person, in the one place the rep goes to find out what happened.
     * A distinct name means that query simply never matches it, and no shipped gate had
     * to be edited to keep the two apart.
     */
    private static final String PROCESS_PARTY = 'Manual Compliance Submission - Joint Owner';
    private static final String RESIDENT    = 'Resident';
    private static final String NON_RESIDENT= 'Non-Resident';
    private static final String ENTITY_TYPE = 'Individual';
    /* The same two words c/mscOwners prints on a row. One vocabulary for one person. */
    private static final String ROLE_PRIMARY = 'Primary Owner';
    private static final String ROLE_JOINT   = 'Joint Owner';
    private static final String PERSON_RT   = 'PersonAccount';
    private static final String ORG_RT      = 'OrganizationAccount';

    /* 3.0 - the three subjects compliance can be asked about. INDIVIDUAL is the
       buyer or a joint owner (a person account either way); PRIMARY_CONTACT is the
       person signing for a company; COMPANY is the company itself. */
    @TestVisible
    private enum EntityKind { INDIVIDUAL, PRIMARY_CONTACT, COMPANY }

    private static final String ENTITY_TYPE_CONTACT = 'Primary Contact';
    private static final String ENTITY_TYPE_COMPANY = 'Company';

    /* 3.0 - the signatory's own submission, logged apart from the buyer's for the
       same reason PROCESS_PARTY is: applyLastComplianceAttempt reads the buyer's
       last attempt, and a signatory's must never be mistaken for it. */
    private static final String PROCESS_SIGNATORY =
        'Manual Compliance Submission - Primary Contact';

    /* 3.0 - a Contact's twins of the fields identity verification owns. Same rule as
       VERIFIED_FIELDS and the same reason: Signzy established them, so the panel
       shows them and never offers them for typing. */
    private static final Set<String> VERIFIED_FIELDS_CONTACT = new Set<String>{
        'IdentityProof__c',
        'Email',
        'MobilePhone',
        'Phone',
        'Birthdate',
        'Nationality__c',
        'UAE_Resident_Status__c',
        'EIDNumber__c',
        'PassportNumber__c',
        'Occupation__c',
        'EmployerBusinessName__c',
        'SourceOfIncome__c',
        'PurposeOfTransaction__c',
        'MailingStreet',
        'MailingCity',
        'MailingState',
        'MailingPostalCode',
        'MailingCountry',
        'NoOfPropertyPurchasedWithModon__c'
    };

    /** 3.0 - the signatory's reading order, the twin of FIELD_ORDER. */
    private static final List<String> FIELD_ORDER_CONTACT = new List<String>{
        'UAE_Resident_Status__c', 'Nationality__c', 'IdentityProof__c',
        'EIDNumber__c', 'PassportNumber__c', 'Birthdate', 'Title',
        'Email', 'MobilePhone', 'Phone',
        'MailingStreet', 'MailingCity', 'MailingState',
        'MailingPostalCode', 'MailingCountry',
        'Occupation__c', 'EmployerBusinessName__c',
        'SourceOfIncome__c', 'OtherSourceOfIncome__c', 'PurposeOfTransaction__c'
    };

    private static final List<String> CONTEXT_FIELDS_CONTACT = new List<String>{
        'DeliveryChannel__c',
        'PaymentMethod__c',
        'NoOfPropertyPurchasedWithModon__c'
    };

    private static final Set<String> REQUIRED_CONTEXT_CONTACT = new Set<String>{
        'DeliveryChannel__c',
        'PaymentMethod__c'
    };

    private static final List<String> DECLARATION_FIELDS_CONTACT = new List<String>{
        'AreYouRealBeneficiaryOfThis__c'
    };

    private static final String PROPERTY_COUNT_FIELD_CONTACT = 'NoOfPropertyPurchasedWithModon__c';
    private static final String ID_PROOF_FIELD_CONTACT = 'IdentityProof__c';

    /* 3.0 - A NAME IS NEVER WRITABLE FROM HERE, whatever any list says.
       Sales_user_cant_update_contact_details (ACTIVE) refuses a Sales role changing
       a saved contact's name, so a name in the allowlist could only ever produce a
       failed save - and the customer card already states that rule per field. This
       is a fence, not a policy: it holds even if MODON adds a name to the label the
       signatory's field list is read from. */
    private static final Set<String> NEVER_WRITE_CONTACT = new Set<String>{
        'FirstName', 'MiddleName', 'LastName', 'Salutation', 'Suffix', 'Name',
        'KYC_Completed_Date__c', 'PassfortApprovalStatus__c',
        'PassfortRiskStatus__c', 'PassfortComment__c', 'profileId__c'
    };

    /**
     * 3.0 - the fields compliance asks of the person signing for a company.
     *
     * Read from MODON's own PassfortContactFieldsToCheck, which is what
     * PassfortTransactionProcessHelper actually sends for a Primary Contact entity -
     * not from Account_Field_Validation__mdt, which holds no Contact rows at all.
     * The label is read, never copied: if compliance changes what it wants, this
     * follows without a deployment. Names are fenced out (NEVER_WRITE_CONTACT) and
     * anything the org has since renamed away is dropped by the describe check.
     */
    private static List<String> signatoryFieldApis() {
        List<String> out = new List<String>();
        String raw;
        try {
            raw = System.Label.PassfortContactFieldsToCheck;
        } catch (Exception e) {
            raw = null;
        }
        if (String.isBlank(raw)) {
            return out;
        }
        Map<String, Schema.SObjectField> conFields = Schema.SObjectType.Contact.fields.getMap();
        Set<String> seen = new Set<String>();
        for (String part : raw.split(',')) {
            String api = part.trim();
            if (String.isBlank(api) || seen.contains(api))      continue;
            if (NEVER_WRITE_CONTACT.contains(api))              continue;
            if (!conFields.containsKey(api))                    continue;
            seen.add(api);
            out.add(api);
        }
        return out;
    }
    private static final String UPLOADED    = 'Uploaded';
    private static final String YES         = 'Yes';
    private static final String NO          = 'No';

    /** A Sales Order in one of these is not a booking compliance should act on. */
    private static final Set<String> DEAD_ORDERS = new Set<String>{
        'Cancelled', 'System Cancelled', 'Voided'
    };

    /**
     * One group for every required detail.
     *
     * They were once split by subject - Identity, Personal, Address - and that division
     * earned nothing: the rep cannot act on all but three of them, so subject told them
     * nothing they could use, and three sub-headings under a section already headed
     * "from identity verification" only made the screen longer. The panel divides on
     * ownership instead, which it reads off each field's readOnly flag, and this stays
     * one section with one count.
     */
    private static final String DETAILS_KEY   = 'identity';
    private static final String DETAILS_LABEL = 'Identity';

    /**
     * Stamped on the customer for compliance and shown to the rep pre-filled.
     * AutoPassfortComplianceService wrote the Contact equivalents; on a Person Account
     * those writes did not take - every person contact it touched still reads blank -
     * so these are the Account person fields instead.
     */
    private static final List<String> CONTEXT_FIELDS = new List<String>{
        'DeliveryChannel__pc',
        'PaymentMethod__pc',
        'NoOfPropertyPurchasedWithModon__pc'
    };

    /**
     * How many properties the customer has bought here. A count, not a judgement: the org
     * knows the number, Passfort scores risk on it, and a rep typing it could only make it
     * wrong - so it is read only, and derived rather than left blank.
     */
    private static final String PROPERTY_COUNT_FIELD = 'NoOfPropertyPurchasedWithModon__pc';

    /**
     * The two the rep must choose before compliance can be told anything.
     *
     * Neither is in Account_Field_Validation__mdt, and they never needed to be: the
     * automation hardcoded them, so they could not be blank and nothing had to check. A
     * person doing the submitting can leave them blank, and they are not decorative -
     * Passfort scores them as s_channel_risk and s_transaction_specific_risk. The client
     * chose the rep answering over a default being applied for them, so this is a gate
     * this class keeps rather than one the metadata states.
     */
    /**
     * What the rep declares about the customer, because nobody else does.
     *
     * Passfort is told this on every submission - AreYouRealBeneficiaryOfThis__c maps to
     * s_are_you_the_real_beneficiary_of_this_transaction - and an unticked box sends "no",
     * which in AML terms asserts that someone else is standing behind this buyer. The
     * identity verification never asks the question and no code anywhere writes the field,
     * so until now every submission has made that assertion about a customer nobody put it
     * to. It is on the panel so that a person answers it.
     *
     * It cannot be gated. The field is a checkbox, so "No" and "never asked" are the same
     * stored value and a gate on it would only look like one. A real gate needs a third
     * state - a picklist, or a declared-on date - which is MODON's field to change.
     */
    /**
     * Where the field's own label does not read as a form label.
     *
     * Every other label on this panel is the org's own and stays that way. These two were
     * written for a page layout, not for a rep to read: "Are you real beneficiary of
     * this?" trails off mid-sentence, and "No of property Purchased with Modon" carries an
     * abbreviation and a stray capital. The wording is otherwise MODON's - the beneficiary
     * one is the Passfort key's own phrase - so nothing here renames a concept, it only
     * finishes the sentence.
     */
    private static final Map<String, String> LABEL_OF = new Map<String, String>{
        'AreYouRealBeneficiaryOfThis__pc'    => 'Real beneficiary of this transaction',
        'NoOfPropertyPurchasedWithModon__pc' => 'Properties purchased with Modon'
    };

    private static final List<String> DECLARATION_FIELDS = new List<String>{
        'AreYouRealBeneficiaryOfThis__pc'
    };

    private static final Set<String> REQUIRED_CONTEXT = new Set<String>{
        'DeliveryChannel__pc',
        'PaymentMethod__pc'
    };

    /**
     * The details identity verification owns, and the rep only reads.
     *
     * Most are taken from CustomerKYCHandler, the only place the verification response is
     * written onto the Account - one block, ending with the KYC_Completed_Date__c stamp
     * this check gates on.
     *
     * Email and Mobile are here for a different reason. The verification does not write
     * them; it REFUSES TO START without them - CustomerKYCHandler will not send the link
     * with either missing, and stops with SignzyEmailMissingErrorMsg or
     * SignzyPhoneMissingErrorMsg. They are the channel the verification travelled through,
     * so by the time this check can be opened at all, both are proved good by the fact
     * that the customer completed it through them. Editing them here would quietly break
     * the join between the identity that was verified and the contact details being sent
     * to compliance, and a change to either is a reason to verify again - which is not
     * something this panel can do.
     *
     * Identity Proof is here for a third reason. Nothing anywhere writes it - but nothing
     * needs to, because residency already decides it: the metadata asks a Resident for an
     * Emirates ID Number and a Non-Resident for a Passport Number, and the required
     * document names split the same way. So it is not an independent judgement, it is a
     * restatement of something the verification already established, and this class
     * derives it rather than asking the rep to retype what the record already says.
     * stampDerivedDetails puts the derived value on the record at submit, so what
     * compliance receives and what the panel showed are the same thing.
     */
    private static final Set<String> VERIFIED_FIELDS = new Set<String>{
        'IdentityProof__pc',
        'PersonEmail',
        'PersonMobilePhone',

        'PersonBirthdate',
        'PersonGenderIdentity',
        'Nationality__pc',
        'UAE_Resident_Status__pc',
        'EIDNumber__pc',
        'PassportNumber__pc',
        'Occupation__pc',
        'EmployerBusinessName__pc',
        'SourceOfIncome__pc',
        'PurposeOfTransaction__pc',
        'PersonMailingStreet',
        'PersonMailingCity',
        'PersonMailingState',
        'PersonMailingPostalCode',
        'PersonMailingCountry',
        'NoOfPropertyPurchasedWithModon__pc'
    };

    /**
     * The order the details read in.
     *
     * The metadata hands them over in developer-name order, which put Mailing Postal Code
     * above Mailing State above Mailing Street and read as though the fields had been
     * shaken out of a bag. This is the order a person reads an identity record: who they
     * are, how to reach them, where they live, what they do and why. Anything the metadata
     * adds later that is not named here keeps its own order and follows at the end.
     */
    private static final List<String> FIELD_ORDER = new List<String>{
        // who they are
        'UAE_Resident_Status__pc',
        'Nationality__pc',
        'IdentityProof__pc',
        'EIDNumber__pc',
        'PassportNumber__pc',
        'PersonBirthdate',
        'PersonGenderIdentity',
        // how to reach them
        'PersonEmail',
        'PersonMobilePhone',
        // where they live
        'PersonMailingStreet',
        'PersonMailingCity',
        'PersonMailingState',
        'PersonMailingPostalCode',
        'PersonMailingCountry',
        // what they do, and why they are buying
        'Occupation__pc',
        'EmployerBusinessName__pc',
        'SourceOfIncome__pc',
        'PurposeOfTransaction__pc'
    };

    private static final String ID_PROOF_FIELD = 'IdentityProof__pc';
    private static final Map<String, String> ID_PROOF_OF = new Map<String, String>{
        RESIDENT     => 'Emirates ID',
        NON_RESIDENT => 'Passport'
    };

    // ======================================================================
    // DTOs
    // ======================================================================

    public class OptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public OptionDTO(String v) { this.label = v; this.value = v; }
    }

    public class FieldDTO {
        @AuraEnabled public String api;
        @AuraEnabled public String label;
        /** raw value for the input; ISO for dates */
        @AuraEnabled public String value;
        /** what the read-only grid prints */
        @AuraEnabled public String display;
        /** text | textarea | email | phone | date | number | picklist */
        @AuraEnabled public String type;
        @AuraEnabled public Boolean filled = false;
        /** identity verification owns this one; the rep reads it and cannot write it */
        @AuraEnabled public Boolean readOnly = false;
        /* 1.x+3 - the submit waits on this one. Set where the counts are made, from the same
           lists the gate reads, so the panel marks exactly what the footer counts. */
        @AuraEnabled public Boolean required = false;
        @AuraEnabled public List<OptionDTO> options;
    }

    public class SectionDTO {
        @AuraEnabled public String key;
        @AuraEnabled public String label;
        @AuraEnabled public Integer ready = 0;
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public List<FieldDTO> fields = new List<FieldDTO>();
    }

    public class DocumentDTO {
        @AuraEnabled public String name;
        @AuraEnabled public Boolean received = false;
        @AuraEnabled public Datetime receivedOn;
    }

    public class ChecklistDTO {
        /** false when the check cannot run at all; blockedReason says why */
        @AuraEnabled public Boolean available = false;
        @AuraEnabled public String blockedReason;

        @AuraEnabled public String customerName;
        /* 2.0 - WHOSE CHECK THIS IS, said by the server on every answer.
           The panel can be switched from one person to another without closing, and the
           reply to a switch is the only thing that may decide which name the header
           carries. Anything the client held over the switch would be the previous
           person's, and a checklist under the wrong name is worse than no checklist. */
        @AuraEnabled public Id partyAccountId;
        @AuraEnabled public String partyName;
        /** "Primary Owner", or their relationship to the buyer. */
        @AuraEnabled public String partyRole;
        @AuraEnabled public Boolean isPrimary = true;
        /**
         * WHICH Sales Order this submission will name, decided by the server.
         *
         * The caller passes the order the rep is LOOKING at, and for a party that can be
         * a unit they do not co-own - on a basket the joint owner may be on unit B while
         * the rep is focused on unit A, and the PassfortTransaction__c would then be
         * filed against a unit they have nothing to do with. resolve picks from the ones
         * they actually hold, so the reply says which it settled on rather than leaving
         * the caller to assume its own request was honoured. Same contract
         * OwnersDTO.focusedSalesOrderId already keeps.
         */
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String residency;
        @AuraEnabled public Boolean kycComplete = false;
        @AuraEnabled public Date kycCompletedDate;
        /** the minute the verification response landed, when the org kept one */
        @AuraEnabled public Datetime kycCompletedOn;

        @AuraEnabled public Boolean alreadySubmitted = false;
        @AuraEnabled public Datetime submittedOn;

        @AuraEnabled public Integer readyCount = 0;
        @AuraEnabled public Integer totalCount = 0;

        @AuraEnabled public List<SectionDTO> sections = new List<SectionDTO>();
        @AuraEnabled public List<DocumentDTO> documents = new List<DocumentDTO>();
        @AuraEnabled public Integer documentsReady = 0;
        @AuraEnabled public Integer documentsTotal = 0;
        @AuraEnabled public List<FieldDTO> declarations = new List<FieldDTO>();
        @AuraEnabled public List<FieldDTO> context = new List<FieldDTO>();
        @AuraEnabled public Integer contextReady = 0;
        @AuraEnabled public Integer contextTotal = 0;

        @AuraEnabled public Boolean canSubmit = false;
        /** the single sentence the footer prints */
        @AuraEnabled public String submitBlockedReason;
    }

    public class SubmitResultDTO {
        @AuraEnabled public Boolean success = false;
        @AuraEnabled public String message;
        @AuraEnabled public Datetime submittedOn;
    }

    /** Everything ONE PERSON's check needs, resolved once. */
    private class Ctx {
        Opportunity opp;
        /** The person being checked: the buyer, or the joint owner named by partyAccountId. */
        Account acc;
        SalesOrder__c so;
        Id contactId;
        String residency;
        String blockedReason;
        Boolean ok = false;
        /* 2.0 - who this check is about. */
        Id partyAccountId;
        Boolean isParty = false;
        /** Their relationship to the buyer, for the panel's header. Null for the buyer. */
        String partyRole;
        /**
         * The buyer's name, kept even when acc is somebody else.
         *
         * Two things need it: the Passfort wrapper's primaryAccountName, which is what
         * classic sets on a joint owner's entity, and the audit log, where "which
         * booking" is the first question anyone reviewing it will ask.
         */
        String buyerName;
        /* 3.0 - which subject this check is about, and the records it reads.
           INDIVIDUAL leaves con/orgAccountId null and behaves exactly as 2.1 did. */
        EntityKind kind = EntityKind.INDIVIDUAL;
        /** The signatory, for PRIMARY_CONTACT. Their record, not the company's. */
        Contact con;
        /** The company, for both organisation kinds. */
        Id orgAccountId;
        /** Whose name the panel and the Passfort payload should carry. */
        String subjectName;
    }

    /* 3.0 - the helpers every per-entity branch reads. One question, one answer,
       so no two places can disagree about what an entity is. */
    private static Boolean isOrg(Ctx c)     { return c.kind != EntityKind.INDIVIDUAL; }
    private static Boolean isCompany(Ctx c) { return c.kind == EntityKind.COMPANY; }
    private static Boolean isSignatory(Ctx c) { return c.kind == EntityKind.PRIMARY_CONTACT; }

    /**
     * 27 Sep 2026: a company is approved by hand on its Power of Attorney Contact and
     * only there, as in MODON's own gate. Guarded with isSet so a context whose contact was read
     * without the field reports "not approved" instead of throwing.
     */
    private static Boolean signatoryManuallyApproved(Ctx c) {
        return c != null && c.con != null && c.con.isSet('Manual_KYC_Approval__c')
            && 'Approved'.equalsIgnoreCase(c.con.Manual_KYC_Approval__c);
    }

    /** The record a checklist reads and writes: the company's contact, or the account. */
    private static Id subjectRecordId(Ctx c) {
        return isSignatory(c) ? (Id) c.contactId : (isCompany(c) ? c.orgAccountId : c.acc.Id);
    }

    private static EntityKind kindOf(String orgEntity) {
        return ENTITY_TYPE_COMPANY.equalsIgnoreCase(orgEntity) || 'COMPANY'.equalsIgnoreCase(orgEntity)
            ? EntityKind.COMPANY
            : EntityKind.PRIMARY_CONTACT;
    }

    // ======================================================================
    // 1 - the checklist
    // ======================================================================

    /**
     * What compliance still needs for this customer. Never throws for missing data and
     * never returns null: the panel renders a state, the same contract getComplianceState
     * already keeps.
     */
    public static ChecklistDTO getChecklist(Id opportunityId, Id salesOrderId) {
        return getChecklist(opportunityId, salesOrderId, null);
    }

    /**
     * 2.0 - the same question, about one named person on this booking.
     *
     * partyAccountId null is the buyer and is byte-for-byte the path that has always run.
     * Set, it is a joint owner - and resolve refuses before reading anything about them
     * unless they are one on a live Sales Order of this Opportunity.
     */
    public static ChecklistDTO getChecklist(Id opportunityId, Id salesOrderId, Id partyAccountId) {
        return getChecklist(opportunityId, salesOrderId, partyAccountId, null);
    }

    /**
     * 3.0 - and about one named SUBJECT of a corporate booking.
     *
     * orgEntity is read only when the buyer is a company: 'Company' or
     * 'Primary Contact'. Null means the signatory, which is the actionable one -
     * an older client that never heard of the parameter therefore lands on the
     * subject it would want.
     */
    @AuraEnabled
    public static ChecklistDTO getChecklist(Id opportunityId, Id salesOrderId,
                                            Id partyAccountId, String orgEntity) {
        ChecklistDTO dto = new ChecklistDTO();
        /* Stamped before anything can fail, so a refusal is still attributable. The panel
           renders the header from these, and a blocked answer that did not say who it was
           about would be drawn under whoever was showing a moment ago. */
        dto.partyAccountId = partyAccountId;
        dto.isPrimary      = (partyAccountId == null);
        try {
            Ctx c = resolve(opportunityId, salesOrderId, partyAccountId, orgEntity);
            dto.blockedReason = c.blockedReason;
            if (c.acc != null) {
                /* 3.0 - the SUBJECT's name, which on a corporate booking is not the
                   account's: a signatory's checklist headed with the company name
                   would be describing the wrong person's documents. */
                dto.partyName = String.isNotBlank(c.subjectName) ? c.subjectName : c.acc.Name;
                dto.partyRole = c.isParty
                    ? c.partyRole
                    : (isSignatory(c) ? ENTITY_TYPE_CONTACT
                        : (isCompany(c) ? ENTITY_TYPE_COMPANY : ROLE_PRIMARY));
            }
            /* Settled before the person gates run, so it is reported even on a refusal -
               "which unit would this have been filed against" is answerable whether or
               not the person can be sent today. */
            dto.salesOrderId = c.so == null ? null : c.so.Id;
            if (!c.ok) {
                return dto;
            }

            dto.available        = true;
            dto.customerName     = String.isNotBlank(c.subjectName) ? c.subjectName : c.acc.Name;
            dto.residency        = c.residency;
            /* 3.0 - the signatory's own verification, not the company's (a company
               has no Signzy journey and its KYC date is null on every record). */
            Date kycDate = isSignatory(c) ? c.con.KYC_Completed_Date__c
                : (isCompany(c) ? null : c.acc.KYC_Completed_Date__c);
            dto.kycComplete      = kycDate != null;
            dto.kycCompletedDate = kycDate;
            dto.kycCompletedOn   = verificationCompletedOn(c);

            Datetime submittedOn = lastSubmissionOn(c);
            dto.alreadySubmitted = isAlreadySubmitted(c);
            dto.submittedOn      = submittedOn;

            buildFieldSections(dto, c);
            buildDocuments(dto, c);
            buildDeclarations(dto, c);
            buildContext(dto, c);
            applySubmitGate(dto, c);
            return dto;

        } catch (Exception e) {
            dto.available = false;
            dto.blockedReason = friendly(e.getMessage());
            return dto;
        }
    }

    // ======================================================================
    // 2 - saving what the rep filled in
    // ======================================================================

    /**
     * Writes the details the rep supplied and hands back the recomputed checklist.
     *
     * Only fields compliance asks for can be written. The allowlist is rebuilt here from
     * the metadata rather than taken from the payload, so a caller naming any other field
     * writes nothing - the entry is dropped and the save carries on.
     */
    public static ChecklistDTO saveDetails(Id opportunityId, Id salesOrderId, String fieldsJson) {
        return saveDetails(opportunityId, salesOrderId, null, fieldsJson);
    }

    /**
     * 2.0 - the same write, on one named person's record.
     *
     * The allowlist is rebuilt per party from the same metadata, so a joint owner is
     * protected by exactly the rules the buyer is: nothing outside what compliance asks
     * for, and nothing the identity verification owns.
     */
    public static ChecklistDTO saveDetails(Id opportunityId, Id salesOrderId,
                                           Id partyAccountId, String fieldsJson) {
        return saveDetails(opportunityId, salesOrderId, partyAccountId, fieldsJson, null);
    }

    /** 3.0 - the same write, on one named subject of a corporate booking. */
    @AuraEnabled
    public static ChecklistDTO saveDetails(Id opportunityId, Id salesOrderId,
                                           Id partyAccountId, String fieldsJson,
                                           String orgEntity) {
        Ctx c = resolve(opportunityId, salesOrderId, partyAccountId, orgEntity);
        if (!c.ok) {
            throw new AuraHandledException(
                String.isBlank(c.blockedReason) ? 'This customer cannot be checked.' : c.blockedReason
            );
        }
        if (String.isBlank(fieldsJson)) {
            return getChecklist(opportunityId, salesOrderId, partyAccountId, orgEntity);
        }

        Map<String, Object> supplied;
        try {
            supplied = (Map<String, Object>) JSON.deserializeUntyped(fieldsJson);
        } catch (Exception e) {
            throw new AuraHandledException('Those details could not be read. Please try again.');
        }
        if (supplied == null || supplied.isEmpty()) {
            return getChecklist(opportunityId, salesOrderId, partyAccountId, orgEntity);
        }

        /* 3.0 - a company writes nothing from here: there is no published list to
           write against, and every field it would carry is shown read-only. */
        if (isCompany(c)) {
            return getChecklist(opportunityId, salesOrderId, partyAccountId, orgEntity);
        }
        Boolean sig = isSignatory(c);

        Set<String> required = new Set<String>();
        if (sig) {
            required.addAll(signatoryFieldApis());
        } else {
            for (Account_Field_Validation__mdt m : requiredMeta(c.residency)) {
                required.add(m.Field_API_Name__c);
            }
        }
        Set<String> allowed = new Set<String>(required);
        allowed.addAll(sig ? CONTEXT_FIELDS_CONTACT : CONTEXT_FIELDS);
        allowed.addAll(sig ? DECLARATION_FIELDS_CONTACT : DECLARATION_FIELDS);
        /* The read-only rule, enforced where it cannot be got round. Removing these from
           the allowlist means a payload naming one writes nothing, whether it came from
           this panel with the control disabled or from a caller that never saw one. */
        if (!(sig ? signatoryManuallyApproved(c) : SalesConsoleVerificationService.isManuallyApproved(c.acc))) {
            allowed.removeAll(sig ? VERIFIED_FIELDS_CONTACT : VERIFIED_FIELDS);
        } /* 18 Sep 2026: on the manual route the rep supplies what Signzy would have */
        /* 3.0 - and a name is never writable, whatever any list said. The org's own
           rule refuses a Sales role changing a saved contact's name, so this could
           only ever produce a failed save. */
        if (sig) {
            allowed.removeAll(NEVER_WRITE_CONTACT);
        }

        Map<String, Schema.SObjectField> accFields = sig
            ? Schema.SObjectType.Contact.fields.getMap()
            : Schema.SObjectType.Account.fields.getMap();

        SObject patch = sig ? (SObject) new Contact(Id = c.contactId)
                            : (SObject) new Account(Id = c.acc.Id);
        Boolean changed = false;

        for (String api : supplied.keySet()) {
            if (!allowed.contains(api) || !accFields.containsKey(api)) {
                continue;
            }
            Schema.DescribeFieldResult f = accFields.get(api).getDescribe();
            if (!f.isUpdateable()) {
                continue;
            }
            Object raw = supplied.get(api);
            String s = raw == null ? null : String.valueOf(raw).trim();

            /* A required detail can be corrected but not emptied. Compliance asked for it,
               so clearing it only moves the customer backwards, and an empty control is
               one stray keystroke away on a panel where every one of them is live. The
               booking context is not required and can still be cleared. */
            if (String.isBlank(s) && required.contains(api)) {
                continue;
            }

            try {
                patch.put(api, coerce(f, s));
            } catch (Exception e) {
                throw new AuraHandledException(f.getLabel() + ' could not be saved. Please check it and try again.');
            }
            changed = true;
        }

        if (changed) {
            try {
                update patch;
            } catch (DmlException e) {
                throw new AuraHandledException(friendly(e.getDmlMessage(0)));
            }
        }
        return getChecklist(opportunityId, salesOrderId, partyAccountId, orgEntity);
    }

    // ======================================================================
    // 3 - the submission
    // ======================================================================

    /**
     * Sends the customer to compliance.
     *
     * Everything the button decided is decided again here. A disabled button is a hint;
     * this is the gate, and it is the only one that counts.
     */
    public static SubmitResultDTO submit(Id opportunityId, Id salesOrderId) {
        return submit(opportunityId, salesOrderId, null);
    }

    /**
     * 2.0 - sends ONE named person to compliance.
     *
     * ONE CALL, ONE ENTITY, ALWAYS. Never one call carrying every party of a booking:
     * createPassfortTransactionRecords opens with deleteDocumentPlaceholders(recordId),
     * which is keyed to a single contact - so an N-entity payload cleans one person's
     * placeholder documents and sends everyone else's blanks to Passfort. Two people go
     * as two submissions, each with its own gate re-run and its own audit line.
     */
    public static SubmitResultDTO submit(Id opportunityId, Id salesOrderId, Id partyAccountId) {
        return submit(opportunityId, salesOrderId, partyAccountId, null);
    }

    /** 3.0 - and one named subject of a corporate booking. */
    @AuraEnabled
    public static SubmitResultDTO submit(Id opportunityId, Id salesOrderId,
                                         Id partyAccountId, String orgEntity) {
        SubmitResultDTO res = new SubmitResultDTO();

        ChecklistDTO check = getChecklist(opportunityId, salesOrderId, partyAccountId, orgEntity);
        if (!check.available) {
            throw new AuraHandledException(
                String.isBlank(check.blockedReason) ? 'This customer cannot be submitted.' : check.blockedReason
            );
        }
        if (check.alreadySubmitted) {
            res.success = false;
            res.message = String.isBlank(check.partyName) || check.isPrimary == true
                ? 'This customer has already been sent for compliance.'
                : check.partyName + ' has already been sent for compliance.';
            res.submittedOn = check.submittedOn;
            return res;
        }
        if (!check.canSubmit) {
            throw new AuraHandledException(
                String.isBlank(check.submitBlockedReason)
                    ? 'Compliance still needs more before this can be sent.'
                    : check.submitBlockedReason
            );
        }

        Ctx c = resolve(opportunityId, salesOrderId, partyAccountId, orgEntity);
        if (!c.ok) {
            throw new AuraHandledException(c.blockedReason);
        }
        /* 3.0 - belt and braces. applySubmitGate already refuses a company, and
           getChecklist above would have thrown; this is the second lock on the door
           that must not open until MODON publishes what a company is checked
           against (GAP 7). */
        if (isCompany(c)) {
            throw new AuraHandledException(companyRefusal());
        }

        // A required document whose file arrived without its row being marked would be
        // deleted by deleteDocumentPlaceholders at the next line, taking the file with
        // it. Put the row right first.
        repairDocumentStatuses(c);

        // What the panel showed as derived has to be what compliance receives.
        stampDerivedDetails(c);

        String result;
        try {
            result = PassfortRelatedEntitiesController.createPassfortTransactionRecords(
                JSON.serialize(buildWrapper(c)),
                c.contactId
            );
        } catch (Exception e) {
            saveLog(c, 'FAILED', 'Exception: ' + e.getMessage());
            throw new AuraHandledException(
                'Compliance could not be contacted just now. Please try again in a moment.'
            );
        }

        if (String.isBlank(result) || !result.containsIgnoreCase('success')) {
            saveLog(c, 'FAILED', String.isBlank(result) ? 'No response' : result);
            throw new AuraHandledException(
                'Compliance did not accept this submission. Sales Operations can help from the account record.'
            );
        }

        saveLog(c, 'SUCCESS', 'Submitted by ' + UserInfo.getName());

        res.success = true;
        res.submittedOn = System.now();
        res.message = 'Sent for compliance.';
        return res;
    }

    // ======================================================================
    // 4 - somewhere for this person's documents to land
    // ======================================================================

    /**
     * 2.0 - creates the Documents__c placeholders compliance looks for, for one party.
     *
     * ON DEMAND, NEVER FOR EVERYBODY. The rep opens one person's check and this runs for
     * that person. Creating slots for every joint owner on the booking would put rows
     * against company accounts that can never go through this route at all, and those
     * rows are litter in MODON's data that nothing here would ever clear up.
     *
     * Silent by design, exactly as the buyer's own call is: it is bookkeeping the rep
     * never asked for, a failure must not stop them opening the check, and the checklist
     * reports its own missing documents a moment later either way.
     *
     * The guard is resolve's, not a second copy: a party who is not on this booking gets
     * no rows created against their contact.
     */
    @AuraEnabled
    public static Integer ensureDocSlots(Id opportunityId, Id salesOrderId, Id partyAccountId) {
        try {
            Ctx c = resolve(opportunityId, salesOrderId, partyAccountId);
            if (!c.ok) {
                return 0;
            }
            return SalesConsoleController.ensureComplianceDocSlots(
                opportunityId, c.isParty ? c.acc.Id : null
            );
        } catch (Exception e) {
            return 0;
        }
    }

    // ======================================================================
    // resolution and guards
    // ======================================================================

    /**
     * One place where every precondition is settled, so getChecklist, saveDetails and
     * submit cannot disagree about whether this customer can be worked on.
     */
    private static Ctx resolve(Id opportunityId, Id salesOrderId) {
        return resolve(opportunityId, salesOrderId, null);
    }

    /**
     * 2.0 - the same place, now settling WHICH PERSON as well as whether.
     *
     * The gates are the buyer's gates, in the buyer's order, run against whoever this
     * check is about. Only two things differ for a joint owner: the ownership guard
     * below, which has no counterpart for the buyer because the buyer IS the booking;
     * and the sentences, which name the person - "the customer has not finished identity
     * verification" is about the wrong human being on a joint owner's panel.
     */
    private static Ctx resolve(Id opportunityId, Id salesOrderId, Id partyAccountId) {
        return resolve(opportunityId, salesOrderId, partyAccountId, null);
    }

    private static Ctx resolve(Id opportunityId, Id salesOrderId, Id partyAccountId,
                               String orgEntity) {
        Ctx c = new Ctx();
        c.partyAccountId = partyAccountId;
        c.isParty        = (partyAccountId != null);

        if (opportunityId == null) {
            c.blockedReason = 'No booking selected.';
            return c;
        }

        List<Opportunity> opps = [
            SELECT Id, AccountId, PrimaryContact__c,
                   Account.Id, Account.Name, Account.IsPersonAccount,
                   Account.PersonContactId, Account.RecordType.DeveloperName,
                   Account.KYC_Completed_Date__c,
                   Account.Manual_KYC_Approval__c,
                   Account.UAE_Resident_Status__pc,
                   Account.PassfortApprovalStatus__pc,
                   Account.PassfortRiskStatus__pc,
                   Account.PassfortComment__pc,
                   /* 3.0 - the COMPANY's own twins. isAlreadySubmitted reads them on
                      the organisation path, where the __pc set above is null by
                      construction. */
                   Account.PassfortApprovalStatus__c,
                   Account.PassfortRiskStatus__c,
                   Account.PassfortComment__c,
                   Account.profileId__c, Account.profileId__pc,
                   /* 3.0 - the organisation's own residency and its signatory's
                      record. Harmless nulls on a person booking. */
                   UAE_Resident_Status__c,
                   PrimaryContact__r.Id, PrimaryContact__r.Name,
                   PrimaryContact__r.Email, PrimaryContact__r.MobilePhone,
                   PrimaryContact__r.KYC_Completed_Date__c,
                   /* 27 Sep 2026: the POA's own manual approval (MODON's Contact process) */
                   PrimaryContact__r.Manual_KYC_Approval__c,
                   PrimaryContact__r.UAE_Resident_Status__c,
                   PrimaryContact__r.PassfortApprovalStatus__c,
                   PrimaryContact__r.PassfortRiskStatus__c,
                   PrimaryContact__r.PassfortComment__c,
                   PrimaryContact__r.profileId__c
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty() || opps[0].Account == null) {
            c.blockedReason = 'This booking has no customer yet.';
            return c;
        }
        c.opp       = opps[0];
        c.buyerName = opps[0].Account.Name;

        if (!c.isParty) {
            c.acc = opps[0].Account;
        } else if (!resolveParty(c, opportunityId, salesOrderId, partyAccountId)) {
            return c;
        }

        if (c.acc.IsPersonAccount != true) {
            /* 3.0 - a company JOINT OWNER is still refused: a corporate co-owner is
               Sales Operations' path from the account record, and nothing on this
               journey asks the questions its entity would need. The BUYER being a
               company is no longer a refusal - it is the organisation path below. */
            if (c.isParty) {
                c.blockedReason = c.acc.Name + ' is a company account. Identity for a company '
                    + 'is proved by the signed KYC and Wealth Form and by Passfort, and a '
                    + 'company joint owner is completed by Sales Operations from the account '
                    + 'record.';
                return c;
            }
            resolveOrganisation(c, opportunityId, salesOrderId, orgEntity);
                return c;
        }

        /* PrimaryContact__c is the BOOKING's contact, so it is a fallback for the buyer
           and never for anybody else - borrowing it would run a joint owner's whole
           check against the buyer's documents and submit the buyer twice. */
        c.contactId = c.acc.PersonContactId;
        if (c.contactId == null && !c.isParty) {
            c.contactId = c.opp.PrimaryContact__c;
        }
        if (c.contactId == null) {
            c.blockedReason = c.isParty
                ? c.acc.Name + ' has no contact record yet, so compliance cannot be checked '
                    + 'here. Sales Operations can put that right.'
                : 'This customer record is not complete enough to check.';
            return c;
        }

        /* 18 Sep 2026: a manual KYC approval on the buyer counts as finished */
        if (c.acc.KYC_Completed_Date__c == null && !SalesConsoleVerificationService.isManuallyApproved(c.acc)) {
            c.blockedReason = c.isParty
                ? c.acc.Name + ' has not finished identity verification yet. Compliance can '
                    + 'be sent once they do.'
                : 'The customer has not finished identity verification yet. Compliance can be sent once they do.';
            return c;
        }

        c.residency = c.acc.UAE_Resident_Status__pc;
        if (String.isBlank(c.residency)) {
            c.blockedReason = c.isParty
                ? 'Set ' + c.acc.Name + '\'s UAE resident status first - it decides what '
                    + 'compliance needs.'
                : 'Set the customer\'s UAE resident status first - it decides what compliance needs.';
            return c;
        }

        /* LAST, and only for the buyer - the order the gates fire in is what decides which
           sentence a booking that trips two of them reports, so the buyer's sequence is
           left exactly as it shipped. A party's order was already settled by resolveParty,
           which cannot run at all without a live one. */
        if (!c.isParty) {
            c.so = liveSalesOrder(opportunityId, salesOrderId);
            if (c.so == null) {
                c.blockedReason = 'There is no live Sales Order for this booking yet.';
                return c;
            }
        }

        c.subjectName = c.acc.Name;
        c.ok = true;
        return c;
    }

    /**
     * 3.0 - the organisation branch (MSC-116, GAP 6 / GAP 5).
     *
     * A corporate booking has two subjects and they are checked differently. The
     * SIGNATORY is a person: they finish a Signzy journey, they hold the twins of
     * every field an individual holds, and they can be corrected and submitted from
     * here. The COMPANY is not: its identity is the signed KYC & Wealth Form and
     * Passfort, its requirements live in metadata MODON has not yet published, and
     * so it opens to show what IS true - its documents and its verdict - and refuses
     * to submit rather than assert a check nobody defined.
     *
     * The gates read the organisation's own records, which is the whole reason the
     * company branch could not simply be un-blocked: residency lives on the
     * Opportunity (a business Account's __pc twin is null by construction), and the
     * KYC date lives on the signatory's Contact, not on the company.
     */
    private static Boolean resolveOrganisation(Ctx c, Id opportunityId, Id salesOrderId,
                                               String orgEntity) {
        c.kind         = kindOf(orgEntity);
        c.orgAccountId = c.acc.Id;
        c.so           = liveSalesOrder(opportunityId, salesOrderId);

        if (isCompany(c)) {
            /* NO GATES AT ALL on the company tab, not even a Sales Order. It exists
               to show what is true about the company - its documents and its
               Passfort verdict - and every gate here would hide exactly that. It
               cannot be submitted in any case (applySubmitGate refuses it outright
               until MODON publishes what a company is checked against), so there is
               nothing a gate would protect. */
            c.subjectName = c.acc.Name;
            c.ok = true;
            return true;
        }

        if (c.opp.PrimaryContact__c == null || c.opp.PrimaryContact__r == null) {
            c.blockedReason = 'This company has no Power of Attorney assigned yet. '
                + 'Assign one from the verification details first - compliance is about '
                + 'the person signing for the company.';
            return false;
        }
        c.con         = c.opp.PrimaryContact__r;
        c.contactId   = c.con.Id;
        c.subjectName = c.con.Name;

        /* 27 Sep 2026: a company's manual approval sits on its POA Contact, and only there */
        if (c.con.KYC_Completed_Date__c == null && !signatoryManuallyApproved(c)) {
            c.blockedReason = c.con.Name + ' has not finished identity verification yet. '
                + 'Compliance can be sent once they do.';
            return false;
        }

        /* The booking's residency, then the signatory's own. A business Account's
           UAE_Resident_Status__pc is null on every record, so reading it here - as
           the individual path does - would refuse every company for ever. */
        c.residency = String.isNotBlank(c.opp.UAE_Resident_Status__c)
            ? c.opp.UAE_Resident_Status__c
            : c.con.UAE_Resident_Status__c;
        if (String.isBlank(c.residency)) {
            c.blockedReason = 'Set the resident status on this booking first - it decides '
                + 'what compliance needs.';
            return false;
        }

        /* LAST, exactly as it is on the individual path: the order the gates fire in
           decides which sentence a booking that trips two of them reports, and "add
           a signatory" is a thing the rep can act on where "there is no Sales Order
           yet" is a thing the journey will produce on its own. */
        if (c.so == null) {
            c.blockedReason = 'There is no live Sales Order for this booking yet.';
            return false;
        }

        c.ok = true;
        return true;
    }

    /**
     * 1.x+4 - the party's Account as the checks read it. Manual_KYC_Approval__c is read so a joint owner
     * approved by manual KYC counts as verified (isManuallyApproved), as the buyer does.
     */
    @TestVisible
    private static List<Account> partyAccounts(Id partyAccountId) {
        return [
            SELECT Id, Name, IsPersonAccount, PersonContactId, RecordType.DeveloperName,
                   KYC_Completed_Date__c, Manual_KYC_Approval__c, UAE_Resident_Status__pc,
                   PassfortApprovalStatus__pc, PassfortRiskStatus__pc, PassfortComment__pc,
                   profileId__c, profileId__pc
            FROM Account
            WHERE Id = :partyAccountId
            LIMIT 1
        ];
    }

    /**
     * THE SECURITY BOUNDARY OF THIS PHASE, and the first thing done with a party Id.
     *
     * The Id arrives from a browser. Before this Account is read - before its name, its
     * residency or one word of its compliance state exists in memory - it has to be a
     * joint owner on a LIVE Sales Order of THIS Opportunity. Without the check, a crafted
     * payload turns getChecklist into a read of any Account in the org and submit into a
     * Passfort transaction for anybody in it. Loophole 13 of the implementation plan.
     *
     * It also settles WHICH Sales Order the submission names. liveSalesOrder returns the
     * order the REP is looking at, which on a basket can be a unit this person does not
     * co-own - and the PassfortTransaction__c would then be filed against a unit they
     * have nothing to do with. So the order is chosen from the ones they actually hold:
     * the focused one if it is among them, and otherwise their oldest holding. Same rule
     * SalesConsoleJointOwnerService.unitForParty uses for the verification link.
     *
     * Returns false with c.blockedReason set; true with c.acc, c.so and c.partyRole.
     */
    private static Boolean resolveParty(Ctx c, Id opportunityId, Id salesOrderId, Id partyAccountId) {
        Map<Id, SalesOrder__c> live = new Map<Id, SalesOrder__c>();
        for (SalesOrder__c so : [
            SELECT Id, Status__c, Modeofpayment__c, CustomerAccount__c
            FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId
            ORDER BY CreatedDate DESC
        ]) {
            if (!DEAD_ORDERS.contains(so.Status__c)) {
                live.put(so.Id, so);
            }
        }
        if (live.isEmpty()) {
            c.blockedReason = 'There is no live Sales Order for this booking yet.';
            return false;
        }

        List<Id> heldInOrder = new List<Id>();
        Set<Id> held = new Set<Id>();
        String role;
        for (JointOwner__c jo : [
            SELECT SalesOrder__c, RelationshipType__c, RelationshipSubType__c
            FROM JointOwner__c
            WHERE JointOwnerAccount__c = :partyAccountId
            AND SalesOrder__c IN :live.keySet()
            ORDER BY CreatedDate
        ]) {
            if (held.add(jo.SalesOrder__c)) {
                heldInOrder.add(jo.SalesOrder__c);
            }
            if (String.isBlank(role)) {
                role = String.isNotBlank(jo.RelationshipSubType__c)
                    ? jo.RelationshipSubType__c
                    : jo.RelationshipType__c;
            }
        }
        if (heldInOrder.isEmpty()) {
            /* Deliberately says nothing about whether that Account exists. A refusal that
               distinguished "not on this booking" from "no such record" would answer a
               question the caller was not entitled to ask. */
            c.blockedReason = 'That person is not a joint owner on this booking, so their '
                + 'compliance cannot be checked here.';
            return false;
        }

        List<Account> parties = partyAccounts(partyAccountId);
        if (parties.isEmpty()) {
            /* Readable to the JointOwner__c row but not to the Account behind it, which
               sharing makes possible on a booking that changed hands. */
            c.blockedReason = 'You do not have access to that person\'s record.';
            return false;
        }

        c.acc       = parties[0];
        c.partyRole = String.isNotBlank(role) ? role : ROLE_JOINT;
        c.so        = live.get(
            salesOrderId != null && held.contains(salesOrderId) ? salesOrderId : heldInOrder[0]
        );
        return true;
    }

    /**
     * The Sales Order compliance attaches to. A basket books one order per unit and the
     * customer goes to compliance once, so the one the rep is looking at wins and the
     * newest live order is the fallback.
     */
    private static SalesOrder__c liveSalesOrder(Id opportunityId, Id salesOrderId) {
        if (salesOrderId != null) {
            List<SalesOrder__c> named = [
                SELECT Id, Status__c, Modeofpayment__c, CustomerAccount__c
                FROM SalesOrder__c
                WHERE Id = :salesOrderId
                LIMIT 1
            ];
            if (!named.isEmpty() && !DEAD_ORDERS.contains(named[0].Status__c)) {
                return named[0];
            }
        }
        List<SalesOrder__c> live = [
            SELECT Id, Status__c, Modeofpayment__c, CustomerAccount__c
            FROM SalesOrder__c
            WHERE Opportunity__c = :opportunityId
            AND Status__c NOT IN :DEAD_ORDERS
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return live.isEmpty() ? null : live[0];
    }

    /**
     * Three independent ways of knowing, because any one of them can be true on its own:
     * Passfort has answered, a profile exists, or a transaction is already in flight.
     */
    private static Boolean isAlreadySubmitted(Ctx c) {
        /* 3.0 - ASKED PER ENTITY. A Primary Contact submission is not an 'Individual'
           one and a Company's is not either; counting the wrong type answers "never
           submitted" for ever, and a panel that believes that offers the same
           submission again on every visit. */
        if (isCompany(c)) {
            if (String.isNotBlank(c.acc.PassfortApprovalStatus__c)) return true;
            if (String.isNotBlank(c.acc.profileId__c))              return true;
            return companyTransactionCount(c.orgAccountId) > 0;
        }
        if (isSignatory(c)) {
            if (c.con == null)                                          return false;
            if (String.isNotBlank(c.con.PassfortApprovalStatus__c))     return true;
            if (String.isNotBlank(c.con.profileId__c))                  return true;
            return contactTransactionCount(c.contactId, ENTITY_TYPE_CONTACT) > 0;
        }
        if (String.isNotBlank(c.acc.PassfortApprovalStatus__pc)) return true;
        if (String.isNotBlank(c.acc.profileId__pc))              return true;
        if (String.isNotBlank(c.acc.profileId__c))               return true;
        return contactTransactionCount(c.contactId, ENTITY_TYPE) > 0;
    }

    @TestVisible
    private static Integer contactTransactionCount(Id contactId, String entityType) {
        if (contactId == null) {
            return 0;
        }
        return [
            SELECT COUNT()
            FROM PassfortTransaction__c
            WHERE Contact__c = :contactId
            AND EntityType__c = :entityType
        ];
    }

    @TestVisible
    private static Integer companyTransactionCount(Id accountId) {
        if (accountId == null) {
            return 0;
        }
        return [
            SELECT COUNT()
            FROM PassfortTransaction__c
            WHERE Account__c = :accountId
            AND EntityType__c = :ENTITY_TYPE_COMPANY
        ];
    }

    private static Datetime lastSubmissionOn(Ctx c) {
        String entityType = isCompany(c) ? ENTITY_TYPE_COMPANY
            : (isSignatory(c) ? ENTITY_TYPE_CONTACT : ENTITY_TYPE);
        Id contactId = c.contactId;
        Id accountId = c.orgAccountId;
        List<PassfortTransaction__c> pts = isCompany(c)
            ? [SELECT CreatedDate FROM PassfortTransaction__c
               WHERE Account__c = :accountId AND EntityType__c = :entityType
               ORDER BY CreatedDate DESC LIMIT 1]
            : [SELECT CreatedDate FROM PassfortTransaction__c
               WHERE Contact__c = :contactId AND EntityType__c = :entityType
               ORDER BY CreatedDate DESC LIMIT 1];
        return pts.isEmpty() ? null : pts[0].CreatedDate;
    }

    /**
     * The minute the verification finished, where the org actually records one.
     *
     * KYC_Completed_Date__c is a Date - it carries no time at all - so the time comes from
     * the verification response itself: the row Signzy's answer created, whose CreatedDate
     * is the moment that answer arrived. CreatedDate rather than LastModifiedDate, because
     * a row edited afterwards would otherwise re-date a verification that finished weeks
     * ago.
     *
     * Keyed on the response's own KYC_Completed_Date__c, not on Full_Journey_Completed__c:
     * nothing in this org writes that flag - every row in the sandbox reads false - so a
     * query on it would have found nothing and the time would never have shown at all.
     *
     * Null when the customer has no completed response row, which is the case for anyone
     * whose completion date was set by hand. The panel then shows the date alone; it never
     * invents a time.
     */
    private static Datetime verificationCompletedOn(Ctx c) {
        if (c.contactId == null) {
            return null;
        }
        try {
            List<KYC_Response__c> rows = [
                SELECT CreatedDate
                FROM KYC_Response__c
                WHERE Contact__c = :c.contactId
                AND KYC_Completed_Date__c != null
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0].CreatedDate;
        } catch (Exception e) {
            return null;
        }
    }

    // ======================================================================
    // the fields
    // ======================================================================

    /**
     * 3.0 - custom metadata cannot be inserted in a test, so the rows can be handed
     * in instead. The company path has no live rows to test against until MODON
     * publishes them (GAP 7), and a checklist nobody can test is a checklist nobody
     * should ship.
     */
    @TestVisible
    private static List<Account_Field_Validation__mdt> requiredMetaOverride;

    private static List<Account_Field_Validation__mdt> requiredMeta(String residency) {
        return requiredMeta(residency, EntityKind.INDIVIDUAL);
    }

    /**
     * The metadata rows that apply to this subject - active, Account, this residency,
     * and this record type.
     *
     * 3.0 - THE RECORD TYPE IS READ FROM BOTH COLUMNS, and that is a fix, not a
     * tidy-up. The rows carry their discriminator in RecordType__c for the eighteen
     * person rows and in Record_Type_Developer_Name__c for the one organisation row -
     * and this method only ever read the first. The organisation row is inactive
     * today, so nothing has gone wrong yet; the day MODON activates it as it stands,
     * a blank RecordType__c would have made it apply to EVERY INDIVIDUAL, putting a
     * company's Unified Number on every person's checklist as an unfillable required
     * detail. Reading both columns means an organisation row can only ever reach the
     * organisation path, whichever column names it.
     */
    private static List<Account_Field_Validation__mdt> requiredMeta(String residency,
                                                                   EntityKind kind) {
        List<Account_Field_Validation__mdt> out = new List<Account_Field_Validation__mdt>();
        List<Account_Field_Validation__mdt> rows = requiredMetaOverride != null
            ? requiredMetaOverride
            : Account_Field_Validation__mdt.getAll().values();
        String wanted = (kind == EntityKind.COMPANY) ? ORG_RT : PERSON_RT;
        for (Account_Field_Validation__mdt m : rows) {
            if (m.Is_Active__c != true)                     continue;
            if (m.Object_API_Name__c != 'Account')          continue;
            if (String.isBlank(m.Field_API_Name__c))        continue;
            // Either column may carry it; a row naming neither applies to the person
            // path only, which is where every unlabelled row has always landed.
            String stated = String.isNotBlank(m.RecordType__c)
                ? m.RecordType__c
                : m.Record_Type_Developer_Name__c;
            if (String.isBlank(stated)) {
                if (kind == EntityKind.COMPANY)             continue;
            } else if (stated != wanted) {
                continue;
            }

            if (String.isNotBlank(m.ResidentType__c)) {
                Boolean applies = false;
                for (String t : m.ResidentType__c.split(',')) {
                    if (t.trim() == residency) { applies = true; break; }
                }
                if (!applies) continue;
            }
            out.add(m);
        }
        return out;
    }

    private static void buildFieldSections(ChecklistDTO dto, Ctx c) {
        /* 3.0 - the signatory's list comes from the label Passfort's own Primary
           Contact payload is built from; Account_Field_Validation__mdt holds no
           Contact rows at all, so there is nothing there to read. */
        if (isSignatory(c)) {
            buildSignatoryFields(dto, c);
            return;
        }

        List<Account_Field_Validation__mdt> meta =
            requiredMeta(c.residency, isCompany(c) ? EntityKind.COMPANY : EntityKind.INDIVIDUAL);
        if (meta.isEmpty()) {
            return;
        }

        Map<String, Schema.SObjectField> accFields = Schema.SObjectType.Account.fields.getMap();

        Set<String> apis = new Set<String>();
        for (Account_Field_Validation__mdt m : meta) {
            if (accFields.containsKey(m.Field_API_Name__c)) {
                apis.add(m.Field_API_Name__c);
            }
        }
        if (apis.isEmpty()) {
            return;
        }

        Account rec = readAccount(subjectRecordId(c), apis);

        SectionDTO section = new SectionDTO();
        section.key   = DETAILS_KEY;
        section.label = DETAILS_LABEL;

        List<FieldDTO> built = new List<FieldDTO>();
        for (Account_Field_Validation__mdt m : meta) {
            String api = m.Field_API_Name__c;
            if (!accFields.containsKey(api)) {
                continue;
            }
            FieldDTO f = describeField(accFields.get(api).getDescribe(), rec);
            if (f.filled != true) {
                applyIdentityProof(f, c);
            }
            built.add(f);
        }

        for (FieldDTO f : inReadingOrder(built)) {
            f.required = true;
            section.fields.add(f);
            section.total++;
            if (f.filled == true) {
                section.ready++;
            }
        }

        if (section.total > 0) {
            dto.sections.add(section);
            dto.totalCount += section.total;
            dto.readyCount += section.ready;
        }
    }

    /**
     * Says which document proved the identity, when the record has not said it itself.
     *
     * Residency decides it and the verification set residency, so the answer is settled
     * before the rep opens this panel. It counts as present - an outstanding count that
     * can never be cleared would hold every submission for ever - and stampDerivedDetails
     * writes it to the record at submit, so nothing is shown that compliance does not
     * then receive.
     */
    /**
     * 3.0 - the signatory's details, read from the Contact they live on.
     *
     * The same shape as the buyer's section and the same rules: what identity
     * verification established is shown and never offered for typing, and the
     * reading order is a person's, not the label's.
     */
    private static void buildSignatoryFields(ChecklistDTO dto, Ctx c) {
        List<String> apis = signatoryFieldApis();
        if (apis.isEmpty()) {
            return;
        }
        Map<String, Schema.SObjectField> conFields = Schema.SObjectType.Contact.fields.getMap();
        Contact rec = readContact(c.contactId, new Set<String>(apis));
        if (rec == null) {
            return;
        }

        SectionDTO section = new SectionDTO();
        section.key   = DETAILS_KEY;
        section.label = DETAILS_LABEL;

        List<FieldDTO> built = new List<FieldDTO>();
        for (String api : apis) {
            FieldDTO f = describeField(conFields.get(api).getDescribe(), rec);
            f.readOnly = VERIFIED_FIELDS_CONTACT.contains(api)
                && !signatoryManuallyApproved(c);
            if (f.filled != true) {
                applyIdentityProof(f, c);
            }
            built.add(f);
        }

        for (FieldDTO f : inReadingOrder(built, FIELD_ORDER_CONTACT)) {
            f.required = true;
            section.fields.add(f);
            section.total++;
            if (f.filled == true) {
                section.ready++;
            }
        }
        if (section.total > 0) {
            dto.sections.add(section);
            dto.totalCount += section.total;
            dto.readyCount += section.ready;
        }
    }

    /** 3.0 - readAccount's twin. Same shape, the other object. */
    private static Contact readContact(Id contactId, Set<String> apis) {
        if (contactId == null || apis == null || apis.isEmpty()) {
            return null;
        }
        String soql = 'SELECT ' + String.join(new List<String>(apis), ', ')
            + ', Id FROM Contact WHERE Id = :contactId LIMIT 1';
        List<Contact> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    private static void applyIdentityProof(FieldDTO f, Ctx c) {
        // 3.0 - the Contact holds the same answer under its own name.
        String proofField = isSignatory(c) ? ID_PROOF_FIELD_CONTACT : ID_PROOF_FIELD;
        if (f.api != proofField) {
            return;
        }
        String proof = derivedIdentityProof(c.residency, f.options);
        if (String.isBlank(proof)) {
            return;
        }
        f.value   = proof;
        f.display = proof;
        f.filled  = true;
    }

    /** Only ever a value the picklist still offers, so nothing derived can be refused. */
    private static String derivedIdentityProof(String residency, List<OptionDTO> options) {
        String proof = ID_PROOF_OF.get(residency);
        if (String.isBlank(proof)) {
            return null;
        }
        if (options == null) {
            return proof;
        }
        for (OptionDTO o : options) {
            if (o.value.equalsIgnoreCase(proof)) {
                return o.value;
            }
        }
        return null;
    }

    /** FIELD_ORDER first, then anything the metadata added that it does not name. */
    private static List<FieldDTO> inReadingOrder(List<FieldDTO> fields) {
        return inReadingOrder(fields, FIELD_ORDER);
    }

    /** 3.0 - the same ordering, against whichever subject's order applies. */
    private static List<FieldDTO> inReadingOrder(List<FieldDTO> fields, List<String> order) {
        Map<String, FieldDTO> byApi = new Map<String, FieldDTO>();
        for (FieldDTO f : fields) {
            byApi.put(f.api, f);
        }
        List<FieldDTO> out = new List<FieldDTO>();
        for (String api : order) {
            if (byApi.containsKey(api)) {
                out.add(byApi.remove(api));
            }
        }
        for (FieldDTO f : fields) {
            if (byApi.containsKey(f.api)) {
                out.add(f);
            }
        }
        return out;
    }

    /** Reads only the fields asked for. Dynamic because the metadata decides the list. */
    private static Account readAccount(Id accountId, Set<String> apis) {
        List<String> cols = new List<String>(apis);
        cols.add('Id');
        /* 18 Sep 2026: so describeField can tell a manually approved buyer (see VERIFIED_FIELDS) */
        if (!apis.contains('Manual_KYC_Approval__c')) { cols.add('Manual_KYC_Approval__c'); }
        /* 27 Sep 2026: lets isManuallyApproved refuse a company account's own approval */
        if (!apis.contains('IsPersonAccount')) { cols.add('IsPersonAccount'); }
        String soql = 'SELECT ' + String.join(cols, ', ')
            + ' FROM Account WHERE Id = :accountId LIMIT 1';
        return Database.query(soql);
    }

    /** True for a buyer Account whose identity was approved manually (no Signzy run). */
    private static Boolean manualRoute(SObject rec) {
        return rec instanceof Account && SalesConsoleVerificationService.isManuallyApproved((Account) rec);
    }

    private static FieldDTO describeField(Schema.DescribeFieldResult f, SObject rec) {
        FieldDTO dto = new FieldDTO();
        dto.api   = f.getName();
        dto.label = LABEL_OF.containsKey(dto.api) ? LABEL_OF.get(dto.api) : f.getLabel();
        dto.type  = uiType(f);

        /* 18 Sep 2026 (testing): Signzy establishes these and the panel shows them - but a
           customer approved MANUALLY never went through Signzy, so the rep is the one who has
           the facts. For them the verified fields are offered for typing. */
        dto.readOnly = VERIFIED_FIELDS.contains(dto.api) && !manualRoute(rec);

        Object raw = rec.get(f.getName());
        dto.filled = raw != null && String.valueOf(raw).trim() != '';

        /* A checkbox always holds one of two values and never a blank, so it is offered as
           the two words a person would actually say rather than as true and false. */
        if (f.getType() == Schema.DisplayType.BOOLEAN) {
            dto.type    = 'picklist';
            dto.options = new List<OptionDTO>{ new OptionDTO(YES), new OptionDTO(NO) };
            dto.value   = raw == true ? YES : NO;
            dto.display = dto.value;
            dto.filled  = true;
            return dto;
        }

        if (dto.filled == true) {
            if (f.getType() == Schema.DisplayType.DATE) {
                Date d = (Date) raw;
                dto.value   = String.valueOf(d);                 // yyyy-MM-dd, what <input type=date> wants
                dto.display = formatDate(d);
            } else if (f.getType() == Schema.DisplayType.DOUBLE
                    || f.getType() == Schema.DisplayType.INTEGER
                    || f.getType() == Schema.DisplayType.CURRENCY
                    || f.getType() == Schema.DisplayType.PERCENT) {
                Decimal dec = (Decimal) raw;
                dto.value   = String.valueOf(dec.setScale(0));
                dto.display = dto.value;
            } else {
                dto.value   = String.valueOf(raw);
                dto.display = dto.value;
            }
        }

        if (f.getType() == Schema.DisplayType.PICKLIST) {
            dto.options = new List<OptionDTO>();
            for (Schema.PicklistEntry pe : f.getPicklistValues()) {
                if (pe.isActive()) {
                    dto.options.add(new OptionDTO(pe.getValue()));
                }
            }
        }
        return dto;
    }

    private static String uiType(Schema.DescribeFieldResult f) {
        Schema.DisplayType t = f.getType();
        if (t == Schema.DisplayType.PICKLIST)                     return 'picklist';
        if (t == Schema.DisplayType.DATE)                         return 'date';
        if (t == Schema.DisplayType.EMAIL)                        return 'email';
        if (t == Schema.DisplayType.PHONE)                        return 'phone';
        if (t == Schema.DisplayType.TEXTAREA)                     return 'textarea';
        if (t == Schema.DisplayType.DOUBLE || t == Schema.DisplayType.INTEGER
            || t == Schema.DisplayType.CURRENCY || t == Schema.DisplayType.PERCENT) return 'number';
        return 'text';
    }

    /** Turns the rep's string back into what the field actually holds. */
    private static Object coerce(Schema.DescribeFieldResult f, String s) {
        if (String.isBlank(s)) {
            return null;
        }
        Schema.DisplayType t = f.getType();
        if (t == Schema.DisplayType.BOOLEAN) {
            return s.equalsIgnoreCase(YES) || s.equalsIgnoreCase('true');
        }
        if (t == Schema.DisplayType.DATE) {
            return Date.valueOf(s);
        }
        if (t == Schema.DisplayType.DOUBLE || t == Schema.DisplayType.CURRENCY
            || t == Schema.DisplayType.PERCENT) {
            return Decimal.valueOf(s);
        }
        if (t == Schema.DisplayType.INTEGER) {
            return Integer.valueOf(s);
        }
        if (t == Schema.DisplayType.PICKLIST) {
            // Anything not on the list is refused rather than written.
            for (Schema.PicklistEntry pe : f.getPicklistValues()) {
                if (pe.isActive() && pe.getValue() == s) {
                    return s;
                }
            }
            throw new IllegalArgumentException('value not in picklist');
        }
        Integer max = f.getLength();
        if (max > 0 && s.length() > max) {
            return s.substring(0, max);
        }
        return s;
    }

    private static final List<String> MONTHS = new List<String>{
        'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    };
    /** "12 Apr 1988" - the console's own date shape. */
    private static String formatDate(Date d) {
        return d == null ? '' : d.day() + ' ' + MONTHS[d.month() - 1] + ' ' + d.year();
    }

    // ======================================================================
    // the documents - status only, never the file
    // ======================================================================

    private static void buildDocuments(ChecklistDTO dto, Ctx c) {
        /* 3.0 - a company's documents are named differently and filed differently:
           the trade licence or certificate of incorporation, keyed to the ACCOUNT.
           A signatory's are the individual set on their own Contact, exactly as a
           buyer's are. */
        List<String> required = isCompany(c)
            ? companyDocNames()
            : SalesConsoleController.requiredComplianceDocNames(c.residency);
        if (required.isEmpty()) {
            return;
        }

        Id docContactId = c.contactId;
        Id docAccountId = c.orgAccountId;
        Map<String, Documents__c> byName = new Map<String, Documents__c>();
        List<Documents__c> rows = isCompany(c)
            ? [SELECT Id, Name, Status__c, LastModifiedDate
               FROM Documents__c
               WHERE Account__c = :docAccountId AND Name IN :required
               ORDER BY LastModifiedDate ASC]
            : [SELECT Id, Name, Status__c, LastModifiedDate
               FROM Documents__c
               WHERE PrimaryContact__c = :docContactId AND Name IN :required
               ORDER BY LastModifiedDate ASC];
        for (Documents__c d : rows) {
            byName.put(d.Name, d);
        }

        Set<Id> withFile = filesPresent(byName.values());

        for (String name : required) {
            DocumentDTO d = new DocumentDTO();
            d.name = name;
            Documents__c row = byName.get(name);
            if (row != null) {
                d.received = row.Status__c == UPLOADED || withFile.contains(row.Id);
                if (d.received == true) {
                    d.receivedOn = row.LastModifiedDate;
                }
            }
            dto.documents.add(d);
            dto.documentsTotal++;
            if (d.received == true) {
                dto.documentsReady++;
            }
        }
    }

    /**
     * 3.0 - the two document names Passfort accepts for a company, read from MODON's
     * own label rather than copied. A resident company files a trade licence; a
     * non-resident one files a certificate of incorporation, and the org has used
     * both, so both are listed and either satisfies the row it names.
     */
    private static List<String> companyDocNames() {
        List<String> out = new List<String>();
        String raw;
        try {
            raw = System.Label.PassfortCompanyDocNames;
        } catch (Exception e) {
            raw = null;
        }
        if (String.isBlank(raw)) {
            return out;
        }
        for (String part : raw.split(',')) {
            if (String.isNotBlank(part)) {
                out.add(part.trim());
            }
        }
        return out;
    }

    /**
     * Which of these rows actually carry a file. The Ids stay here - nothing derived from
     * a ContentDocument ever reaches a DTO.
     *
     * 2.1 - public, and called by SalesConsoleBookingListController for the booking's own
     * document checklist. Same object, same question, same answer; a second copy of it
     * over there would be free to drift. Both callers are `with sharing`.
     */
    public static Set<Id> filesPresent(List<Documents__c> rows) {
        Set<Id> out = new Set<Id>();
        if (rows == null || rows.isEmpty()) {
            return out;
        }
        Set<Id> ids = new Set<Id>();
        for (Documents__c d : rows) {
            ids.add(d.Id);
        }
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :ids
        ]) {
            out.add(cdl.LinkedEntityId);
        }
        return out;
    }

    /**
     * Marks a required document Uploaded when its file is there but the row still says
     * Pending Upload.
     *
     * Not cosmetic: createPassfortTransactionRecords opens by deleting every Pending
     * Upload row for this contact, so without this the file is destroyed on the way to
     * compliance and the submission carries one document fewer than the rep was shown.
     */
    private static void repairDocumentStatuses(Ctx c) {
        List<String> required = SalesConsoleController.requiredComplianceDocNames(c.residency);
        if (required.isEmpty()) {
            return;
        }
        List<Documents__c> rows = [
            SELECT Id, Name, Status__c
            FROM Documents__c
            WHERE PrimaryContact__c = :c.contactId
            AND Name IN :required
        ];
        if (rows.isEmpty()) {
            return;
        }
        Set<Id> withFile = filesPresent(rows);
        List<Documents__c> fix = new List<Documents__c>();
        for (Documents__c d : rows) {
            if (d.Status__c != UPLOADED && withFile.contains(d.Id)) {
                fix.add(new Documents__c(Id = d.Id, Status__c = UPLOADED));
            }
        }
        if (!fix.isEmpty()) {
            update fix;
        }
    }

    // ======================================================================
    // booking context
    // ======================================================================

    private static void buildDeclarations(ChecklistDTO dto, Ctx c) {
        /* 3.0 - a company makes no declaration of its own; the person signing for it
           makes it, on the very field MSC-113's customer card already writes. */
        if (isCompany(c)) {
            return;
        }
        Boolean sig = isSignatory(c);
        List<String> wanted = sig ? DECLARATION_FIELDS_CONTACT : DECLARATION_FIELDS;
        Map<String, Schema.SObjectField> fieldMap = sig
            ? Schema.SObjectType.Contact.fields.getMap()
            : Schema.SObjectType.Account.fields.getMap();
        Set<String> apis = new Set<String>();
        for (String api : wanted) {
            if (fieldMap.containsKey(api)) {
                apis.add(api);
            }
        }
        if (apis.isEmpty()) {
            return;
        }
        SObject rec = sig ? (SObject) readContact(c.contactId, apis)
                          : (SObject) readAccount(c.acc.Id, apis);
        if (rec == null) {
            return;
        }
        for (String api : wanted) {
            if (!fieldMap.containsKey(api)) {
                continue;
            }
            FieldDTO f = describeField(fieldMap.get(api).getDescribe(), rec);
            dto.declarations.add(f);
            /* Counted with the booking context, because the panel shows them as one group
               and a rail that counts two of the three would be lying about the group it
               points at. It does not join the submit gate: a checkbox cannot be blank, so
               it is always ready and could never hold anything up. */
            dto.contextTotal++;
            if (f.filled == true) {
                dto.contextReady++;
            }
        }
    }

    private static void buildContext(ChecklistDTO dto, Ctx c) {
        /* 3.0 - the company's own booking context is part of the company checklist
           MODON has not published; nothing is asked here until it is. */
        if (isCompany(c)) {
            return;
        }
        Boolean sig = isSignatory(c);
        List<String> wanted = sig ? CONTEXT_FIELDS_CONTACT : CONTEXT_FIELDS;
        Set<String> requiredContext = sig ? REQUIRED_CONTEXT_CONTACT : REQUIRED_CONTEXT;
        Map<String, Schema.SObjectField> accFields = sig
            ? Schema.SObjectType.Contact.fields.getMap()
            : Schema.SObjectType.Account.fields.getMap();
        Set<String> apis = new Set<String>();
        for (String api : wanted) {
            if (accFields.containsKey(api)) {
                apis.add(api);
            }
        }
        if (apis.isEmpty()) {
            return;
        }
        SObject rec = sig ? (SObject) readContact(c.contactId, apis)
                          : (SObject) readAccount(c.acc.Id, apis);
        if (rec == null) {
            return;
        }

        for (String api : wanted) {
            if (!accFields.containsKey(api)) {
                continue;
            }
            FieldDTO f = describeField(accFields.get(api).getDescribe(), rec);
            /* Only the derived count is filled in. The rep's two are shown exactly as the
               record holds them, blank included: a suggestion put into the control was
               indistinguishable from a saved value, so clearing one and saving looked as
               though the old value had come back - the save had worked and the panel had
               simply re-suggested over the top of it. Nothing is put in a control here
               that the record does not already say. */
            if (f.filled != true && f.readOnly == true) {
                applyDerivedContext(f, c);
            }
            dto.context.add(f);
            if (requiredContext.contains(api)) {
                f.required = true;
                dto.contextTotal++;
                if (f.filled == true) {
                    dto.contextReady++;
                }
            }
        }
    }

    /**
     * Fills a count the rep cannot supply and should not have to.
     *
     * It counts as present once derived, the same reasoning as Identity Proof: nothing on
     * this screen can clear it, so leaving it outstanding would only be a permanent blank.
     */
    private static void applyDerivedContext(FieldDTO f, Ctx c) {
        String countField = isSignatory(c) ? PROPERTY_COUNT_FIELD_CONTACT : PROPERTY_COUNT_FIELD;
        if (f.api != countField) {
            return;
        }
        /* 3.0 - on a corporate booking the properties are the COMPANY's; the
           signatory signs for them. CustomerKYCHandler counts Sales Orders against
           an account and is indifferent to its record type. */
        f.value   = String.valueOf(propertyCount(isOrg(c) ? c.orgAccountId : c.acc.Id));
        f.display = f.value;
        f.filled  = true;
    }

    /**
     * MODON's own count, called rather than copied.
     *
     * This class had its own version of the query and it had already drifted: it excluded
     * Cancelled, System Cancelled and Voided, and missed Cancelled SR, so a customer with
     * a cancelled-SR booking counted one higher here than everywhere else in the org.
     * CustomerKYCHandler defines what this number means; there is no second definition.
     */
    private static Integer propertyCount(Id accountId) {
        try {
            Decimal n = CustomerKYCHandler.getNoOfPropertyWithModon(accountId);
            return n == null ? 0 : n.intValue();
        } catch (Exception e) {
            return 0;
        }
    }

    // ======================================================================
    // the gate
    // ======================================================================

    /**
     * One sentence, naming the nearest thing standing in the way. A list of everything
     * wrong is what the sections already show; the footer says what to do next.
     */
    private static void applySubmitGate(ChecklistDTO dto, Ctx c) {
        if (dto.alreadySubmitted == true) {
            dto.canSubmit = false;
            dto.submitBlockedReason = 'Already sent for compliance.';
            return;
        }

        /* 3.0 - a company is never submitted from here. Not "not yet configured" as
           an accident of empty metadata, but a stated refusal: compliance has
           published no field requirements for a company (GAP 7), so a submission
           would assert a check nobody defined. Sales Operations owns that path from
           the account record until MODON says otherwise. */
        if (isCompany(c)) {
            dto.canSubmit = false;
            dto.submitBlockedReason = companyRefusal();
            return;
        }

        Integer missingFields = dto.totalCount - dto.readyCount;
        Integer missingDocs   = dto.documentsTotal - dto.documentsReady;

        /* 3.0 - AN EMPTY REQUIREMENT SET IS NOT A PASS. With no rules published this
           read "nothing outstanding" and armed the button - the one shape in which
           this panel could have sent a customer it had checked nothing about. */
        if (dto.totalCount == 0 && dto.contextTotal == 0) {
            dto.canSubmit = false;
            dto.submitBlockedReason = 'Compliance has not published what it needs for this '
                + 'customer yet, so this cannot be sent from here. Sales Operations can '
                + 'complete it from the account record.';
            return;
        }

        /* 3.0 - the signatory's payload is read by Passfort's Primary Contact
           endpoint, which dereferences their email without checking it. A blank one
           fails inside an async batch where the rep would never see it, so it is
           refused here, in words, while they can still fix it. */
        if (isSignatory(c) && c.con != null) {
            List<String> missingReach = new List<String>();
            if (String.isBlank(c.con.Email))       missingReach.add('email address');
            if (String.isBlank(c.con.MobilePhone)) missingReach.add('mobile number');
            if (!missingReach.isEmpty()) {
                dto.canSubmit = false;
                dto.submitBlockedReason = 'Add the signatory\'s '
                    + String.join(missingReach, ' and ') + ' on the Customer step first.';
                return;
            }
        }

        // Named, not counted: there are only ever two, and naming them saves the rep
        // hunting a screen that has already told them everything else is in.
        Set<String> requiredContext = isSignatory(c) ? REQUIRED_CONTEXT_CONTACT : REQUIRED_CONTEXT;
        List<String> missingContext = new List<String>();
        for (FieldDTO f : dto.context) {
            if (requiredContext.contains(f.api) && f.filled != true) {
                missingContext.add(f.label);
            }
        }

        /* 3.0 - a signatory's documents are shown but do not hold the gate: the org
           collects the individual set against a BUYER's contact, and no process
           files them for a company's signatory, so holding on them would deadlock
           a submission Passfort itself scores on fields. */
        if (isSignatory(c)) {
            missingDocs = 0;
        }

        if (missingFields == 0 && missingDocs == 0 && missingContext.isEmpty()) {
            dto.canSubmit = true;
            dto.submitBlockedReason = null;
            return;
        }

        dto.canSubmit = false;
        List<String> parts = new List<String>();
        if (missingFields > 0) {
            parts.add(missingFields + (missingFields == 1 ? ' detail' : ' details'));
        }
        if (missingDocs > 0) {
            parts.add(missingDocs + (missingDocs == 1 ? ' document' : ' documents'));
        }
        if (!missingContext.isEmpty()) {
            parts.add(String.join(missingContext, ' and '));
        }
        dto.submitBlockedReason = String.join(parts, ', ') + ' still needed';
    }

    /** 3.0 - one sentence, said the same way wherever a company is refused. */
    private static String companyRefusal() {
        return 'Compliance has not yet published its field requirements for a company, so a '
            + 'company cannot be sent from here. Sales Operations completes a company\'s '
            + 'submission from the account record.';
    }

    /**
     * Writes the details this class derived, so the record and the submission agree.
     *
     * Only ever fills a blank: a value already on the customer - set by Sales Operations
     * from the account record, say - is left exactly as it is. A stamp that will not take
     * must never stop a submission the rep has already made, so it is not allowed to throw.
     */
    private static void stampDerivedDetails(Ctx c) {
        /* 3.0 - the signatory's derived details land on their Contact, under the
           twins of the same names. A company stamps nothing: it has no identity
           proof of its own and its checklist is not published. */
        if (isCompany(c)) {
            return;
        }
        Boolean sig = isSignatory(c);
        String idProofField = sig ? ID_PROOF_FIELD_CONTACT : ID_PROOF_FIELD;
        String countField   = sig ? PROPERTY_COUNT_FIELD_CONTACT : PROPERTY_COUNT_FIELD;
        Id subjectId        = sig ? (Id) c.contactId : c.acc.Id;
        Map<String, Schema.SObjectField> accFields = sig
            ? Schema.SObjectType.Contact.fields.getMap()
            : Schema.SObjectType.Account.fields.getMap();

        Set<String> apis = new Set<String>();
        for (String api : new List<String>{ idProofField, countField }) {
            if (accFields.containsKey(api)) {
                apis.add(api);
            }
        }
        if (apis.isEmpty()) {
            return;
        }

        SObject rec = sig ? (SObject) readContact(subjectId, apis)
                          : (SObject) readAccount(subjectId, apis);
        if (rec == null) {
            return;
        }
        SObject patch = sig ? (SObject) new Contact(Id = subjectId)
                            : (SObject) new Account(Id = subjectId);
        Boolean changed = false;
        String ID_PROOF_FIELD = idProofField;
        String PROPERTY_COUNT_FIELD = countField;

        if (apis.contains(ID_PROOF_FIELD) && isBlankOn(rec, ID_PROOF_FIELD)) {
            List<OptionDTO> options = new List<OptionDTO>();
            for (Schema.PicklistEntry pe :
                    accFields.get(ID_PROOF_FIELD).getDescribe().getPicklistValues()) {
                if (pe.isActive()) {
                    options.add(new OptionDTO(pe.getValue()));
                }
            }
            String proof = derivedIdentityProof(c.residency, options);
            if (String.isNotBlank(proof)) {
                patch.put(ID_PROOF_FIELD, proof);
                changed = true;
            }
        }

        if (apis.contains(PROPERTY_COUNT_FIELD) && isBlankOn(rec, PROPERTY_COUNT_FIELD)) {
            patch.put(PROPERTY_COUNT_FIELD,
                Decimal.valueOf(propertyCount(isOrg(c) ? c.orgAccountId : c.acc.Id)));
            changed = true;
        }

        if (!changed) {
            return;
        }
        try {
            update patch;
        } catch (Exception e) {
            // The submission is the point; a stamp that will not take must not stop it.
        }
    }

    private static Boolean isBlankOn(SObject rec, String api) {
        Object v = rec.get(api);
        return v == null || String.valueOf(v).trim() == '';
    }

    // ======================================================================
    // the submission payload and the audit trail
    // ======================================================================

    /**
     * The same shape the Sales Order page's own button builds. Sent through
     * PassfortRelatedEntitiesController so there is exactly one way into Passfort.
     */
    private static List<PassfortRelatedEntitiesController.EntityWrapper> buildWrapper(Ctx c) {
        PassfortRelatedEntitiesController.EntityWrapper w =
            new PassfortRelatedEntitiesController.EntityWrapper();
        Boolean sig = isSignatory(c);
        w.EntityRecordId      = c.contactId;
        w.EntityAPIName       = 'Contact';
        /* 3.0 - the entity type is the routing: PassfortTransactionProcessHelper
           picks its endpoint from it, so a signatory sent as 'Individual' would be
           scored against the wrong Passfort profile shape entirely. */
        w.EntityType          = sig ? ENTITY_TYPE_CONTACT : ENTITY_TYPE;
        /* And the name is the SUBJECT's. c.acc.Name on a corporate booking is the
           company - a signatory filed under it would be the wrong person's profile. */
        w.Name                = sig ? c.con.Name : c.acc.Name;
        w.parentRecordId      = c.so.Id;
        w.parentObjectName    = 'SalesOrder__c';
        w.RiskStatus          = sig ? c.con.PassfortRiskStatus__c : c.acc.PassfortRiskStatus__pc;
        w.ApprovalStatus      = sig ? c.con.PassfortApprovalStatus__c : c.acc.PassfortApprovalStatus__pc;
        w.passfortComment     = sig ? c.con.PassfortComment__c : c.acc.PassfortComment__pc;
        w.IsCommercialProject = false;
        w.IsSecondaryMarket   = false;
        /* 2.0 - what classic sets on a joint owner's entity and leaves null on the
           buyer's: PassfortRelatedEntitiesController.formEntityWrapperRecord's
           eight-argument overload, called only from its joint-owner loop.
           SAID PLAINLY, BECAUSE IT MATTERS TO WHOEVER READS THIS NEXT:
           createPassfortTransactionRecords never reads the field. It reaches no column on
           PassfortTransaction__c and changes no stored record. It is set so that a console
           submission and a classic submission produce the same payload for the same
           person - parity, not effect - and if a later version of MODON's code starts
           reading it, ours already says the right thing. */
        if (c.isParty) {
            w.primaryAccountName = c.buyerName;
        }
        return new List<PassfortRelatedEntitiesController.EntityWrapper>{ w };
    }

    /**
     * Mirrors the automation's log shape so the Verification card's last-attempt read
     * works for a manual submission too, and so both live in one place for whoever
     * reviews them.
     */
    private static void saveLog(Ctx c, String status, String detail) {
        try {
            String process = c.isParty
                ? PROCESS_PARTY
                : (isSignatory(c) ? PROCESS_SIGNATORY : PROCESS);
            String summary = status
                + (c.isParty ? ' | Joint owner: ' : ' | Customer: ') + c.acc.Name
                + ' | Account: '    + c.acc.Id
                + (c.isParty ? ' | Buyer: ' + c.buyerName : '')
                + ' | SalesOrder: ' + c.so.Id
                + ' | By: '         + UserInfo.getName();
            if (summary.length() > 255) {
                summary = summary.substring(0, 252) + '...';
            }
            Logger__c log = LoggerService.createAPILog(
                process, CLASS_NAME, 'submit', detail, summary, status, process
            );
            log.Sales_Order__c = c.so.Id;
            LoggerService.save(new List<Logger__c>{ log });
        } catch (Exception ignored) {
            // A logging problem must never lose a submission the rep already made.
        }
    }

    /** Salesforce's own wording is not for a sales rep. */
    private static String friendly(String raw) {
        if (String.isBlank(raw)) {
            return 'Something went wrong. Please try again.';
        }
        String m = raw.toLowerCase();
        if (m.contains('insufficient access') || m.contains('insufficient_access')) {
            return 'You do not have access to this customer record.';
        }
        if (m.contains('unable to lock row')) {
            return 'This record is being updated by another process. Please try again in a moment.';
        }
        if (m.contains('field_custom_validation_exception') || m.contains('field integrity')) {
            return 'One of these details was not accepted. Please check it and try again.';
        }
        return raw;
    }
}