/**
 * AurelixManualKycService - what a manual KYC submission still needs, for the Sales Console.
 *
 * Version  Author       Date         Detail
 * 4.18     Aurelix Dev  30 Sep 2026  earlierSignedFileId: after a regeneration, the newest signed form from an
 *                                    earlier round stays reachable from the panel (R2-13).
 * 4.17     Aurelix Dev  29 Sep 2026  The panel follows the current round (document service 1.10): signedReceived
 *                                    counts only a signed form filed this round, formGenerated only a "KYC Form" file
 *                                    from this KYC round (kycRoundStart); generationInFlight passes on the gate's.
 * 4.16     Aurelix Dev  29 Sep 2026  A renewal's signed copy is filed too: fileSignedCopy links the new signed copy
 *                                    beside last round's file when every file on "KYC Form - Signed" predates the
 *                                    current round (currentRoundStart). signedFileId now opens the newest file.
 * 4.15     Aurelix Dev  29 Sep 2026  A company's manual KYC works on AurelixPoaResolver.bookingSubject (the primary
 *                                    contact, the POA as MODON confirmed, else the POA row), so no POA row is needed.
 * 4.14     Aurelix Dev  28 Sep 2026  THE JOINT OWNER'S MANUAL KYC ROUTE (28 Sep: check the Sales App for a
 *                                    manual KYC for a joint owner and, since it has one, give the drawer the
 *                                    buyer's route). evaluateParty, getPartyManualKycFiles, submitPartyManualKyc,
 *                                    getPartyApprovalTrail, getPartyManualOutcome and requestPartyKycFormGeneration
 *                                    serve one person named by Account Id, guarded by
 *                                    SalesConsoleJointOwnerService.partyProblem. They reuse the buyer's code:
 *                                    evaluatePerson and getManualOutcome now run through evaluatePersonSubject and
 *                                    outcomeFor, and submitManualKyc through submitFor, with the buyer's behaviour
 *                                    unchanged. The submission is MODON's ManualKYCController.submitForApproval on
 *                                    the person's Account (process Submit_for_Manual_KYC, owner-only submit, as in
 *                                    the Sales App). The form is rendered on their own "KYC Form" row and not sent
 *                                    by the automated DocuSign route, which would address the buyer
 *                                    (AurelixKycFormGenerator 1.5).
 * 4.13     Aurelix Dev  27 Sep 2026  A company is offered Generate too, as in MODON's Sales App: getManualOutcome
 *                                    takes generationOffered from AurelixKycGenerationGate 2.0 (applicable
 *                                    for a person and for a company's primary contact) instead of persons
 *                                    only, and reads the gate's verdict, MODON's own validator, for both.
 * 4.12     Aurelix Dev  27 Sep 2026  Passport expiry is no longer a console requirement (decided 27 Sep
 *                                    2026). CONSOLE_PASSPORT_FIELDS keeps PassportNumber__pc only, so the
 *                                    3.2 defaults no longer add PassportExpiryDate__pc to missingFields,
 *                                    to the Generate gate, or to the manual outcome. MODON has no
 *                                    Account_KYC_Validation__mdt row for it and its mandatory rule on Lead
 *                                    and Opportunity is inactive. An expired date is still refused where
 *                                    the identity rule reads it (AurelixIdentityRuleService 1.1).
 * 4.11     Aurelix Dev  27 Sep 2026  A COMPANY'S MANUAL KYC NEVER FALLS BACK TO THE COMPANY ACCOUNT
 *                                    (27 Sep, after MODON's answer of 26 Sep: the company's
 *                                    KYC is checked on its Primary Contact). manualKycSubjectFor
 *                                    answered the company Account when no POA resolved, so the
 *                                    outcome, the approval trail and a submit could all land on the
 *                                    company record, which MODON's gate no longer reads. It now
 *                                    answers null for a company without a POA. The supporting file
 *                                    is uploaded to, and listed from, the POA Contact, where the
 *                                    approval request and MODON's "For Approval" renaming happen;
 *                                    before this it went onto the company Account, next to nothing.
 *                                    The person route is unchanged.
 * 4.10     Aurelix Dev  24 Sep 2026  A FAILED FORM CAN BE ASKED FOR AGAIN. 4.9 named the
 *                                    failure but offered nothing to do about it, so a representative whose
 *                                    render had failed was stuck. formRetryable says the console may offer
 *                                    the attempt again: the row failed AND the gate permits a fresh request
 *                                    (AurelixKycGenerationGate 1.5, which stops treating a spent request
 *                                    flag as an outstanding one). It is deliberately the gate's verdict and
 *                                    not simply "it failed", so a retry is never offered on a row that is
 *                                    still short of a field or a file: there the missing list is the route
 *                                    forward, as it always was.
 *                                    requestKycFormGeneration is UNCHANGED, and that is the decision, not
 *                                    an omission. Nothing is cleared before the new attempt: Nintex is
 *                                    called directly by AurelixKycFormGenerator every time, so no status
 *                                    word or error message feeds the render, and clearing them first would
 *                                    only create a window in which a row that had failed read as pending.
 *                                    If the retry fails, MODON's logError writes the fresh reason over the
 *                                    old one and the row stays at Error, so the representative sees the
 *                                    same state with a newer explanation and may try again - never a worse
 *                                    one.
 * 4.9      Aurelix Dev  24 Sep 2026  ONE EXACT WORD WAS DOING THE WORK OF A WHOLE PICKLIST. 4.8 called the
 *                                    form generated only when Document_Status__c read exactly 'Generated',
 *                                    so every other value fell through to the request flag and the panel
 *                                    said "Form requested" for a row that plainly held its PDF (seen in testing,
 *                                    24 Sep). The field was read from the org: a RESTRICTED picklist of
 *                                    four values, Pending, Sent, Error and Generated. Of those only
 *                                    Generated and Error are written by anything deployed - MODON's
 *                                    DocumentAutoGenerateService, plus our own generator writing Generated -
 *                                    checked against all 1935 Apex classes and all 252 Flows in the org.
 *                                    So the word is no longer the test. The PDF's existence is now the
 *                                    file on the "KYC Form" row (documentFilePresent,
 *                                    AurelixKycGenerationGate 1.4), and the status word only adds to it:
 *                                    Sent counts as produced, since nothing can be sent unproduced; Error
 *                                    is reported as a failure of its own instead of reading as a request;
 *                                    and any value outside the four is reported as unrecognised rather
 *                                    than silently read as a request. Pending stays "requested", which is
 *                                    what it means.
 * 4.8      Aurelix Dev  24 Sep 2026  REQUESTED IS NOT GENERATED. The console could only tell that a form
 *                                    had been ASKED for (generationRequested, the row's
 *                                    Auto_Generate_Document__c, which nothing ever clears), so a buyer
 *                                    whose PDF was already produced still read "The form is being
 *                                    generated". formGenerated says the PDF exists: the
 *                                    row's Document_Status__c has reached Generated, the value
 *                                    AurelixKycFormGenerator writes and MODON's autoSendDocuSign fires
 *                                    on. The three states are therefore distinct on the record:
 *                                    requested, generated, and signed back (signedReceived).
 * 4.7      Aurelix Dev  24 Sep 2026  FILES ARE REPORTED AS FILES. getManualOutcome passed the gate's
 *                                    union list straight through as missingFields, so the console
 *                                    listed "Passport (file)" among the fields and told the rep to
 *                                    complete it in Update KYC. missingFields now
 *                                    carries the gate's FIELDS only and the new missingFiles carries
 *                                    the identity documents, which the console asks for as an upload.
 *                                    generationBlockedReason still names everything, as before.
 * 4.6      Aurelix Dev  23 Sep 2026  A COMPANY'S MANUAL KYC BELONGS TO ITS POWER OF ATTORNEY.
 *                                    MODON confirmed on 22 Sep that its new Contact process
 *                                    ("Submit for Manual KYC Contact", 21 Sep) is for the POA, and their
 *                                    ManualKYCController 1.1 routes by record: an Account goes to the
 *                                    Account process, a Contact to the Contact one. The console sent a
 *                                    company to the COMPANY account, where the approval could never
 *                                    describe the person who is actually verified. It now submits, reads
 *                                    and reports the POA Contact for a company (manualKycSubjectFor),
 *                                    and the Account for a person, as before.
 * 4.5      Aurelix Dev  22 Sep 2026  MODON changed Account_KYC_Validation__mdt on 22 Sep
 *                                    (AccountKYCValidationInvocable 1.3/1.4): 23 Contact rows for a
 *                                    company's POA, scoped by the new Parent_Record_Type__c, and field
 *                                    paths such as Account.Trade_License_Number__c. Read as before, a
 *                                    person buyer was asked for the company rows too (Trade License
 *                                    Number, Nature of Business) and could never be ready, and the
 *                                    Account.* fields always read as missing. Now: Parent_Record_Type__c
 *                                    is honoured (appliesToParent), a comma separated Record_Type__c is
 *                                    split, and one-level paths are queried and read (readTarget,
 *                                    readValue).
 * 4.4      Aurelix Dev  21 Sep 2026  The request is found by account only. As a console representative the
 *                                    4.3 query failed with "Illegal filter on ProcessInstance": the
 *                                    ProcessDefinition.DeveloperName filter is refused for that user, though
 *                                    not for an administrator, so the box fell back to the field and showed
 *                                    a recalled request as pending (browser check, SCW-141). The account
 *                                    carries five approval processes (merge, VAT, trade licence, bank
 *                                    details, manual KYC), so the manual-KYC request is picked in Apex by
 *                                    the Submit_for_Manual_KYC definition's Id. If that Id cannot be read
 *                                    the trail says nothing rather than guess, and the box falls back to
 *                                    the field.
 * 4.3      Aurelix Dev  21 Sep 2026  THE REQUEST ITSELF (getApprovalTrail). Manual_KYC_Approval__c says
 *                                    Submitted from the moment a request goes in, but MODON's
 *                                    Submit_for_Manual_KYC approval process has no recall action: a
 *                                    recalled request leaves the field at Submitted with nobody holding
 *                                    it, and the console then showed "pending" for ever and offered no
 *                                    new request (test test2, 18 Sep - SCW-138/139). The request's own
 *                                    record - its latest ProcessInstance and steps - now says when it
 *                                    went, who holds it, and whether it is still live. A rejection
 *                                    also carries its date, approver and comment into getManualOutcome.
 *                                    Read only.
 * 4.2      Aurelix Dev  18 Sep 2026  THE SIGNED COPY. Seen live: DocuSign's write-back for a form
 *                                    sent by MODON's automated route lands on the "KYC Form" row
 *                                    itself, named exactly like the original ("KYC Form Manual
 *                                    <name>.pdf") beside a CertificateOfCompletion - not with the
 *                                    "_completed" suffix MODON's moveManualKYCFormToSigned waits
 *                                    for, so the "KYC Form - Signed" row stayed empty and the gate
 *                                    still refused. getManualOutcome now reconciles on read: when
 *                                    the row's envelope is Completed (dfsle__EnvelopeStatus__c, or
 *                                    failing that a CertificateOfCompletion beside a newer copy),
 *                                    the newest signed copy is LINKED to the "KYC Form - Signed"
 *                                    row - the same re-parenting MODON's mover does, keyed on
 *                                    DocuSign's own status instead of a file name. MODON's link
 *                                    trigger then marks the row Uploaded, exactly as for any file.
 * 4.1      Aurelix Dev  18 Sep 2026  requestKycFormGeneration delegates to AurelixKycFormGenerator.
 *                                    The flag route below (3.0) never generated anything: MODON's
 *                                    trigger generates on after-insert only. See the generator.
 * 4.0      Aurelix Dev  18 Sep 2026  MSC-176 / MSC-178 (B6 + B7).
 *                                    B7 - the supporting file is OPTIONAL (ATTACHMENT_REQUIRED =
 *                                    false): the internal app relaxed it on 17 Sep and
 *                                    ManualKYCController.submitForApproval already accepts a null
 *                                    document Id. Reason and comment stay mandatory.
 *                                    B7 - the generation rows are "KYC Form" (the target) and
 *                                    "KYC Form - Signed" (the signed copy) on the buyer's CONTACT
 *                                    (PrimaryContact__c) - the rows the internal app's "Generate
 *                                    Documents" creates and MODON's signed-file mover
 *                                    (moveManualKYCFormToSigned) matches on. "KYC and Wealth Form"
 *                                    on the Account was wrong: that name belongs to the Sales Order
 *                                    template set and exists only after a booking.
 *                                    B8 - getManualOutcome and requestKycFormGeneration take their
 *                                    verdict from AurelixKycGenerationGate (the union of Option B,
 *                                    MODON's field set, gender and identity-proof files, plus the
 *                                    Nintex template configuration). Generate is refused with the
 *                                    gate's own sentence.
 *                                    B6 - ORGANISATIONS. evaluate no longer reports "not
 *                                    configured": the subject is the authorised POA Contact
 *                                    (AurelixPoaResolver), the requirements are the Contact rows of
 *                                    Account_KYC_Validation__mdt where MODON has any, else a
 *                                    documented console default (nationality, residency, gender,
 *                                    email, mobile, birthdate, the B2 identity rule on the
 *                                    Contact) plus the company's licence number, licence expiry and
 *                                    Billing address. Submission still goes to
 *                                    ManualKYCController.submitForApproval with the COMPANY
 *                                    Account, whose approval AurelixKycEligibilityService already
 *                                    honours. Update KYC for a company opens on the POA Contact
 *                                    (subjectId), which makes MODON's AccountKycController return
 *                                    the contact, its Mailing address, the company fields and the
 *                                    company's Billing address. Generation stays hidden for
 *                                    companies by decision.
 * 3.2      Aurelix Dev  17 Sep 2026  MSC-174 (B2). Option B gains the PASSPORT. The decision of
 *                                    17 Sep makes passport number and expiry mandatory for every
 *                                    person buyer, but Account_KYC_Validation__mdt carries no
 *                                    passport row, so the console adds two requirements of its
 *                                    own - PassportNumber__pc and PassportExpiryDate__pc, both
 *                                    residencies - ONLY while no row targets those fields (matched
 *                                    by field API name, active or not). The day MODON adds a
 *                                    passport row it wins and the defaults step aside with no
 *                                    deployment. Each such requirement carries consoleDefault =
 *                                    true so a screen can say where it came from. rulesOverride
 *                                    (@TestVisible) lets the tests prove the hand-over without
 *                                    inserting custom metadata, which a test cannot do.
 * 3.1      Aurelix Dev  08 Sep 2026  signedFileId, so the console can OPEN the signed form rather
 *                                    than only report that it exists. loadsignedkycform was
 *                                    re-inspected and deliberately not reused - see the DTO.
 * 3.0      Aurelix Dev  07 Sep 2026  Phase 3B, the post-approval route. Once Sales Operations
 *                                    APPROVES a manual KYC the customer still has to be
 *                                    captured, generated, signed and re-evaluated - and none of
 *                                    that existed in the console. Added, all wrapping MODON
 *                                    chains verified in the org and none of them modified:
 *                                      capture   AccountKycController.resolveContext / loadForm
 *                                                / saveForm  (their whole field engine - the
 *                                                mapping, addresses, dependent picklists and
 *                                                date rules are theirs, not reimplemented)
 *                                      generate  Documents__c.Auto_Generate_Document__c = true
 *                                                -> DocumentTriggerHelper.autoGenerateAndSend
 *                                                -> DocumentAutoGenerateService (Nintex)
 *                                                -> Document_Status__c 'Generated'
 *                                                -> Auto_Send_DocuSign_Email__c -> queueable
 *                                                -> dfsle envelope -> DocuSign
 *                                      signed    the signed Documents__c row and its file
 *                                    THE GATE BEFORE GENERATION IS OURS AND IS OPTION B: the
 *                                    residency-aware metadata check below, never MODON's
 *                                    validator, which ignores ResidentType__c (Q-H).
 * 2.0      Aurelix Dev  07 Sep 2026  Phase 3, the console's manual route. The validator gains the
 *                                    three things the screen needs - the subject Account, the
 *                                    configured reasons, and the files already on record - plus
 *                                    submitManualKyc, which enforces reason + comment +
 *                                    ATTACHMENT and then hands the submission to MODON's own
 *                                    ManualKYCController.submitForApproval. Their class is
 *                                    CALLED, never modified, and never granted to the community
 *                                    permission set: wrapping it here keeps the console's Apex
 *                                    surface to Aurelix classes only.
 * 1.0      Aurelix Dev  07 Sep 2026  Phase 3, Option B. Reads Account_KYC_Validation__mdt
 *                                    DIRECTLY and honours ResidentType__c. Person buyers only.
 *                                    Organisation returns "not configured" - by instruction,
 *                                    no corporate rule is invented here. Read-only: this class
 *                                    reports, it does not submit and it blocks nothing.
 *
 * OWNERSHIP. Aurelix-owned. Everything it reads is MODON's configuration and is READ, never
 * modified:
 *   Account_KYC_Validation__mdt   the manual-KYC field requirements
 *   Account / Contact             the values those requirements are checked against
 *
 * WHY OPTION B - WHY WE READ THE METADATA INSTEAD OF CALLING MODON'S VALIDATOR.
 * AccountKYCValidationInvocable.validateKYC is callable and was verified as such, but it never
 * reads ResidentType__c. Every rule it finds is applied to every buyer, so a NON-RESIDENT is
 * asked for an Emirates ID - EIDNumber is configured Resident-only and the invocable cannot see
 * that. Calling it unchanged would import that defect into the console. Option B reads the same
 * rows and applies the residency dimension MODON already configured but does not consume.
 * This is NOT a fix to MODON's code: their class is untouched and still behaves as it does.
 * The defect is reported as Q-H.
 *
 * ORGANISATIONS (4.0). Until 18 Sep 2026 this class reported companies as "not configured"
 * because Account_KYC_Validation__mdt holds no organisation rows (verified 07 Sep: four rows, all
 * PersonAccount). The 17 Sep decision names the subject - the authorised POA Contact - and the
 * approval target - the company Account - so evaluateOrganisation now checks a documented console
 * default (CONSOLE_CONTACT_FIELDS, the B2 identity rule, COMPANY_FIELDS). MODON's Contact rows,
 * the day they add any, replace the contact default with no code change.
 *
 * SCOPE. Organisation KYC ELIGIBILITY is a different question and is already answered by
 * AurelixKycEligibilityService (Option 2, Phase 1). Nothing here weakens or replaces it.
 */
public with sharing class AurelixManualKycService {

    private static final String RT_ORGANISATION = 'Organization Account';
    /* The developer name MODON's four configured rows carry. A person buyer is evaluated
       against the person rules whatever record type their own Account happens to hold. */
    @TestVisible
    private static final String RT_PERSON_ACCOUNT = 'PersonAccount';
    /* Documents__c.Name values, verbatim from the org (485 pairs on record). Matched by NAME,
       which is how every other KYC document check in this project works. */
    @TestVisible
    private static final String DOC_KYC_FORM   = AurelixKycDocumentService.DOC_KYC_FORM;
    @TestVisible
    private static final String DOC_KYC_SIGNED = AurelixKycDocumentService.DOC_SIGNED_KYC;
    private static final String RT_ORG_DEV     = 'OrganizationAccount';

    private static final String OBJ_ACCOUNT     = 'Account';
    private static final String OBJ_CONTACT     = 'Contact';

    /* 4.15 - a company booking with no primary contact and no POA row: nobody to work on. */
    @TestVisible
    private static final String NO_COMPANY_SUBJECT =
        'Primary Contact is not set on this booking. Add the Primary Contact before starting manual KYC.';

    /* Manual KYC submission rules, as MODON's existing quick action enforces them. Mandatory by
       decision (§13); Q-G asks the business whether the attachment may ever relax. Reported so
       the console form enforces the same three, never a looser set. */
    public static final Boolean REASON_REQUIRED     = true;
    public static final Boolean COMMENT_REQUIRED    = true;
    /** 4.0 - optional since 17 Sep 2026, as the internal app now has it. */
    public static final Boolean ATTACHMENT_REQUIRED = false;

    /* 4.0 - B6. The console's default requirements for a company's authorised signatory, used only
       while Account_KYC_Validation__mdt holds no Contact rows. Field API names on Contact. */
    @TestVisible
    private static final List<String> CONSOLE_CONTACT_FIELDS = new List<String>{
        'Nationality__c', 'UAE_Resident_Status__c', 'GenderIdentity', 'Email', 'MobilePhone', 'Birthdate'
    };
    /* 4.0 - B6. What compliance needs of the company itself. Field API names on Account. */
    @TestVisible
    private static final List<String> COMPANY_FIELDS = new List<String>{
        'UnifiedNumber__c', 'TradeLicenseExpiryDate__c',
        'BillingStreet', 'BillingCity', 'BillingState', 'BillingPostalCode', 'BillingCountry'
    };

    /** One configured requirement and whether the buyer currently satisfies it. */
    public class RequirementDTO {
        @AuraEnabled public String fieldApiName;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String label;
        @AuraEnabled public String appliesToResidency;
        @AuraEnabled public Boolean satisfied = false;
        /** 3.2 - true when the console supplied this requirement because MODON's metadata has none for the field. */
        @AuraEnabled public Boolean consoleDefault = false;
        /** 4.0 - 'Buyer', 'Signatory' or 'Company': whose record the field is on. */
        @AuraEnabled public String subject;
    }

    /* 3.2 - the passport pair the console requires of every person buyer while MODON's metadata is
       silent on it. Field API names on Account; labels come from the org's own describe.
       4.12 - the number only: passport expiry is optional (decided 27 Sep 2026). */
    @TestVisible
    private static final List<String> CONSOLE_PASSPORT_FIELDS = new List<String>{
        'PassportNumber__pc'
    };

    /** 3.2 - tests inject rows here; null means read Account_KYC_Validation__mdt. */
    @TestVisible
    private static List<Account_KYC_Validation__mdt> rulesOverride;

    /** Everything the console needs to render the manual-KYC step. */
    public class ManualKycStateDTO {
        /** 'Person' or 'Organisation'. */
        @AuraEnabled public String customerType;
        /** FALSE for organisations today - MODON has configured no organisation rules. */
        @AuraEnabled public Boolean configured = false;
        /** Why it is not configured, in words a representative can act on. */
        @AuraEnabled public String notConfiguredReason;
        /** True when every applicable requirement is satisfied. */
        @AuraEnabled public Boolean ready = false;
        /** Labels of what is still missing, for display. */
        @AuraEnabled public List<String> missingFields = new List<String>();
        /** Every rule that applied, satisfied or not. */
        @AuraEnabled public List<RequirementDTO> requirements = new List<RequirementDTO>();
        /** The residency the rules were filtered by; null when it is not set on the buyer. */
        @AuraEnabled public String residency;
        /** A problem that stops evaluation rather than a missing field. */
        @AuraEnabled public String blockedReason;

        @AuraEnabled public Boolean reasonRequired     = REASON_REQUIRED;
        @AuraEnabled public Boolean commentRequired    = COMMENT_REQUIRED;
        @AuraEnabled public Boolean attachmentRequired = ATTACHMENT_REQUIRED;

        /** 2.0 - the subject the submission is made against; null when it could not be resolved. */
        @AuraEnabled public Id accountId;
        /** 2.0 - MODON's own KYC_Manual_Reason__c values, so the console offers no reason of its own. */
        @AuraEnabled public List<OptionDTO> reasonOptions = new List<OptionDTO>();
        /** 4.0 - the person whose details are captured: the buyer's Account, or the POA Contact. */
        @AuraEnabled public Id subjectId;
        @AuraEnabled public String subjectName;
        /** 4.0 - for an organisation, the company the approval lands on. */
        @AuraEnabled public String companyName;
    }

    /** A picklist value, exactly as the field defines it. */
    public class OptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public OptionDTO(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    /**
     * What manual KYC still needs for the buyer on this Opportunity. Pure read - no DML, no
     * submission, no gate.
     */
    @AuraEnabled(cacheable=false)
    public static ManualKycStateDTO evaluate(Id opportunityId) {
        ManualKycStateDTO dto = new ManualKycStateDTO();
        if (opportunityId == null) {
            dto.blockedReason = 'No booking was provided.';
            return dto;
        }

        List<Opportunity> opps = [
            SELECT Id, AccountId, PrimaryContact__c,
                   Account.Name, Account.IsPersonAccount, Account.RecordType.Name,
                   PrimaryContact__r.AccountId,
                   PrimaryContact__r.Name,
                   PrimaryContact__r.UAE_Resident_Status__c,
                   PrimaryContact__r.Account.RecordType.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        if (opps.isEmpty()) {
            dto.blockedReason = 'Booking not found.';
            return dto;
        }
        Opportunity opp = opps[0];

        /* 4.0 - the buyer type is the COMMERCIAL buyer's, as the eligibility service decides it. */
        String accountRt = opp.Account == null ? null : opp.Account.RecordType.Name;
        Boolean isOrganisation = opp.AccountId != null && opp.Account.IsPersonAccount != true
            && String.isNotBlank(accountRt) && accountRt.trim().equalsIgnoreCase(RT_ORGANISATION);
        if (!isOrganisation && opp.PrimaryContact__c != null) {
            String recordTypeName = opp.PrimaryContact__r.Account.RecordType.Name;
            isOrganisation = String.isNotBlank(recordTypeName)
                             && recordTypeName.trim().equalsIgnoreCase(RT_ORGANISATION);
        }
        dto.customerType = isOrganisation ? 'Organisation' : 'Person';

        if (isOrganisation) {
            return evaluateOrganisation(opp, dto);
        }

        if (opp.PrimaryContact__c == null) {
            dto.blockedReason = 'No customer is attached to this booking yet. '
                              + 'Add the customer before starting manual KYC.';
            return dto;
        }
        return evaluatePerson(opp, dto);
    }

    /**
     * 4.0 - B6. ORGANISATION. The subject is the authorised POA Contact, and from 4.11 the
     * approval and the supporting file land on that Contact too. Requirements: MODON's Contact
     * rows where any exist, else the console default; then the identity rule on the Contact;
     * then the company's own fields.
     */
    private static ManualKycStateDTO evaluateOrganisation(Opportunity opp, ManualKycStateDTO dto) {
        Id companyId = opp.AccountId;
        dto.accountId     = null;   /* 4.11 - the POA Contact, set once it resolves */
        dto.companyName   = opp.Account == null ? null : opp.Account.Name;
        dto.reasonOptions = manualReasonOptions();
        dto.configured    = true;

        /* 4.15 - the primary contact (the POA, as MODON reads it); a POA row only when none is set */
        Id poaId = AurelixPoaResolver.bookingSubject(companyId, opp.PrimaryContact__c);
        if (poaId == null) {
            dto.blockedReason = NO_COMPANY_SUBJECT;
            return dto;
        }
        /* 4.11 - the upload target. The approval request and MODON's "For Approval" renaming
           both happen on the POA Contact, so the supporting file belongs there too. */
        dto.accountId = poaId;
        List<Contact> poas = [
            SELECT Id, Name, UAE_Resident_Status__c FROM Contact WHERE Id = :poaId LIMIT 1
        ];
        if (poas.isEmpty()) {
            dto.blockedReason = 'The authorised signatory could not be read.';
            return dto;
        }
        Contact poa = poas[0];
        dto.subjectId   = poa.Id;
        dto.subjectName = poa.Name;
        String residency = poa.UAE_Resident_Status__c;
        dto.residency = String.isBlank(residency) ? null : residency.trim();

        /* MODON's Contact rows, if they ever add them; the console default until then. */
        List<Account_KYC_Validation__mdt> configuredRows = rulesOverride != null
            ? rulesOverride
            : [
                SELECT Field_API_Name__c, Field_Label__c, Object_API_Name__c,
                       Record_Type__c, Record_Type_Developer_Name__c, ResidentType__c, Is_Active__c,
                       Parent_Record_Type__c
                FROM Account_KYC_Validation__mdt
            ];
        List<Account_KYC_Validation__mdt> contactRules = new List<Account_KYC_Validation__mdt>();
        for (Account_KYC_Validation__mdt r : configuredRows) {
            if (r.Is_Active__c != true) { continue; }
            if (String.isBlank(r.Object_API_Name__c)
                || !r.Object_API_Name__c.trim().equalsIgnoreCase(OBJ_CONTACT)) { continue; }
            if (!appliesToRecordType(r, RT_ORG_DEV)) { continue; }
            // 4.5: a Contact row may be scoped to its account's record type
            if (!appliesToParent(r, RT_ORG_DEV)) { continue; }
            if (!appliesToResidency(r, dto.residency)) { continue; }
            contactRules.add(r);
        }
        Boolean consoleDefault = contactRules.isEmpty();
        if (consoleDefault) {
            for (String field : CONSOLE_CONTACT_FIELDS) {
                contactRules.add(new Account_KYC_Validation__mdt(
                    Field_API_Name__c             = field,
                    Field_Label__c                = AurelixIdentityRuleService.fieldLabel(OBJ_CONTACT, field),
                    Object_API_Name__c            = OBJ_CONTACT,
                    Record_Type_Developer_Name__c = RT_ORG_DEV,
                    Is_Active__c                  = true
                ));
            }
        }
        SObject contactRow = readTarget(OBJ_CONTACT, poa.Id, contactRules);
        for (Account_KYC_Validation__mdt r : contactRules) {
            RequirementDTO req    = new RequirementDTO();
            req.fieldApiName       = r.Field_API_Name__c;
            req.objectApiName      = OBJ_CONTACT;
            req.label              = String.isNotBlank(r.Field_Label__c) ? r.Field_Label__c : r.Field_API_Name__c;
            req.appliesToResidency = r.ResidentType__c;
            req.consoleDefault     = consoleDefault;
            req.subject            = 'Signatory';
            Object val = readValue(contactRow, r.Field_API_Name__c);
            req.satisfied = val != null && String.valueOf(val).trim() != '';
            if (!req.satisfied) { dto.missingFields.add(req.label); }
            dto.requirements.add(req);
        }

        /* the B2 identity rule, on the Contact's own fields */
        AurelixIdentityRuleService.IdentityStateDTO identity = AurelixIdentityRuleService.stateFor(poa.Id);
        if (identity != null && identity.missing != null) {
            for (String label : identity.missing) {
                if (!dto.missingFields.contains(label)) { dto.missingFields.add(label); }
            }
        }

        /* the company */
        // 4.5: skip a company field MODON's POA rows already ask for as Account.<field>
        Set<String> askedByModon = new Set<String>();
        for (Account_KYC_Validation__mdt r : contactRules) {
            String f = r.Field_API_Name__c == null ? '' : r.Field_API_Name__c.trim().toLowerCase();
            if (f.startsWith('account.')) { askedByModon.add(f.substringAfter('.')); }
        }
        List<Account_KYC_Validation__mdt> companyRules = new List<Account_KYC_Validation__mdt>();
        for (String field : COMPANY_FIELDS) {
            if (askedByModon.contains(field.toLowerCase())) { continue; }
            companyRules.add(new Account_KYC_Validation__mdt(
                Field_API_Name__c  = field,
                Field_Label__c     = AurelixIdentityRuleService.fieldLabel(OBJ_ACCOUNT, field),
                Object_API_Name__c = OBJ_ACCOUNT,
                Is_Active__c       = true
            ));
        }
        SObject companyRow = readTarget(OBJ_ACCOUNT, companyId, companyRules);
        for (Account_KYC_Validation__mdt r : companyRules) {
            RequirementDTO req = new RequirementDTO();
            req.fieldApiName    = r.Field_API_Name__c;
            req.objectApiName   = OBJ_ACCOUNT;
            req.label           = r.Field_Label__c;
            req.consoleDefault  = true;
            req.subject         = 'Company';
            Object val = readValue(companyRow, r.Field_API_Name__c);
            req.satisfied = val != null && String.valueOf(val).trim() != '';
            if (!req.satisfied) { dto.missingFields.add('Company ' + req.label); }
            dto.requirements.add(req);
        }

        dto.ready = dto.missingFields.isEmpty();
        return dto;
    }

    /**
     * PERSON - Option B. The configured rules, filtered by object, record type and residency,
     * then checked against the buyer's own values.
     */
    private static ManualKycStateDTO evaluatePerson(Opportunity opp, ManualKycStateDTO dto) {
        return evaluatePersonSubject(dto, opp.PrimaryContact__r.AccountId, opp.PrimaryContact__c,
            opp.PrimaryContact__r.Name, opp.PrimaryContact__r.UAE_Resident_Status__c);
    }

    /**
     * 4.14: the person evaluation for any person: the buyer (above) or a joint owner (evaluateParty).
     * The body is the one evaluatePerson always had; only where the four values come from moved.
     */
    private static ManualKycStateDTO evaluatePersonSubject(
        ManualKycStateDTO dto, Id accountId, Id contactId, String name, String residency
    ) {
        /* 2.0 - what the submission screen needs: who it is for, and MODON's own reasons. */
        dto.accountId     = accountId;
        dto.reasonOptions = manualReasonOptions();
        /* 4.0 - the capture subject is the person's own Account */
        dto.subjectId     = accountId;
        dto.subjectName   = name;

        dto.residency = String.isBlank(residency) ? null : residency.trim();

        /* 3.2 - every row, active or not: an inactive passport row is still MODON's decision about
           the passport and must silence the console's default. `rules` keeps only the active ones,
           exactly the set 1.0 queried. */
        List<Account_KYC_Validation__mdt> configuredRows = rulesOverride != null
            ? rulesOverride
            : [
                SELECT Field_API_Name__c, Field_Label__c, Object_API_Name__c,
                       Record_Type__c, Record_Type_Developer_Name__c, ResidentType__c, Is_Active__c,
                       Parent_Record_Type__c
                FROM Account_KYC_Validation__mdt
            ];
        List<Account_KYC_Validation__mdt> rules = new List<Account_KYC_Validation__mdt>();
        for (Account_KYC_Validation__mdt r : configuredRows) {
            if (r.Is_Active__c == true) { rules.add(r); }
        }

        /* Keep only the rules that apply to THIS buyer. */
        List<Account_KYC_Validation__mdt> applicable = new List<Account_KYC_Validation__mdt>();
        for (Account_KYC_Validation__mdt r : rules) {
            if (!appliesToRecordType(r, RT_PERSON_ACCOUNT)) { continue; }
            // 4.5: the company POA rows (Parent_Record_Type__c = OrganizationAccount) are not for a person
            if (!appliesToParent(r, RT_PERSON_ACCOUNT))   { continue; }
            if (!appliesToResidency(r, dto.residency))    { continue; }
            applicable.add(r);
        }

        /* Nothing configured at all is a configuration gap, not a pass. Said plainly rather
           than reported as "ready", which is the vacuous-success trap MODON's validator falls
           into for organisations. */
        if (rules.isEmpty()) {
            dto.configured = false;
            dto.notConfiguredReason =
                'No active manual KYC field requirements are configured.';
            return dto;
        }
        dto.configured = true;

        /* 3.2 - the console's passport pair, only where MODON has no row for the field. Filtered by
           residency like any other rule (they apply to both, so this is for symmetry, not effect). */
        Set<String> consoleDefaultFields = new Set<String>();
        for (Account_KYC_Validation__mdt d : consolePassportDefaults(configuredRows)) {
            if (!appliesToResidency(d, dto.residency)) { continue; }
            applicable.add(d);
            consoleDefaultFields.add(d.Field_API_Name__c.toLowerCase());
        }

        /* Split by target object, then read each object once with only the fields it owns. */
        Map<String, List<Account_KYC_Validation__mdt>> byObject =
            new Map<String, List<Account_KYC_Validation__mdt>>();
        for (Account_KYC_Validation__mdt r : applicable) {
            String obj = String.isBlank(r.Object_API_Name__c)
                         ? OBJ_ACCOUNT : r.Object_API_Name__c.trim();
            if (!byObject.containsKey(obj)) {
                byObject.put(obj, new List<Account_KYC_Validation__mdt>());
            }
            byObject.get(obj).add(r);
        }

        for (String obj : byObject.keySet()) {
            Id targetId = obj.equalsIgnoreCase(OBJ_CONTACT) ? contactId : accountId;
            if (targetId == null) { continue; }
            SObject target = readTarget(obj, targetId, byObject.get(obj));

            for (Account_KYC_Validation__mdt r : byObject.get(obj)) {
                RequirementDTO req    = new RequirementDTO();
                req.fieldApiName       = r.Field_API_Name__c;
                req.objectApiName      = obj;
                req.label              = String.isNotBlank(r.Field_Label__c)
                                         ? r.Field_Label__c : r.Field_API_Name__c;
                req.appliesToResidency = r.ResidentType__c;
                req.consoleDefault     = String.isNotBlank(r.Field_API_Name__c)
                                         && consoleDefaultFields.contains(r.Field_API_Name__c.toLowerCase());
                req.subject            = 'Buyer';

                Object val = readValue(target, r.Field_API_Name__c);
                req.satisfied = val != null && String.valueOf(val).trim() != '';
                if (!req.satisfied) { dto.missingFields.add(req.label); }
                dto.requirements.add(req);
            }
        }

        if (String.isBlank(dto.residency)) {
            /* Residency decides which rules apply, so an unset value is itself a gap. Named
               separately from a missing field so the rep knows why the list may be short. */
            dto.missingFields.add('UAE Resident Status');
        }

        dto.ready = dto.missingFields.isEmpty();
        return dto;
    }

    /**
     * MODON's own record-type semantics, reproduced so behaviour matches theirs: an explicit
     * developer name wins; otherwise the text field is compared against developer name or label;
     * a blank record type applies universally. Generic on purpose - it will match organisation
     * rows unchanged the day MODON adds them.
     */
    @TestVisible
    private static Boolean appliesToRecordType(Account_KYC_Validation__mdt r, String rtDevName) {
        if (String.isNotBlank(r.Record_Type_Developer_Name__c)) {
            return r.Record_Type_Developer_Name__c.trim().equalsIgnoreCase(rtDevName);
        }
        if (String.isNotBlank(r.Record_Type__c)) {
            // 4.5: MODON allows a comma separated list here since 22 Sep
            return listHas(r.Record_Type__c, rtDevName);
        }
        return true;
    }

    /**
     * 4.5: Parent_Record_Type__c (MODON, 22 Sep) scopes a row to the record type of the account
     * that owns the record, e.g. a company POA Contact row. Blank means any.
     */
    @TestVisible
    private static Boolean appliesToParent(Account_KYC_Validation__mdt r, String parentRtDevName) {
        if (String.isBlank(r.Parent_Record_Type__c)) { return true; }
        return listHas(r.Parent_Record_Type__c, parentRtDevName);
    }

    /** 4.5: true when a comma separated list holds the value, ignoring case and spaces. */
    private static Boolean listHas(String csv, String value) {
        if (String.isBlank(csv) || String.isBlank(value)) { return false; }
        for (String part : csv.split(',')) {
            if (part.trim().equalsIgnoreCase(value.trim())) { return true; }
        }
        return false;
    }

    /**
     * 3.2 - MSC-174 (B2). The console's own passport requirements, built only for the fields no
     * configured row (active or inactive) already names. In-memory metadata rows, never inserted:
     * they ride the same evaluation as MODON's, so a screen cannot tell them apart except by the
     * consoleDefault flag - which is the point.
     */
    @TestVisible
    private static List<Account_KYC_Validation__mdt> consolePassportDefaults(
        List<Account_KYC_Validation__mdt> configured
    ) {
        Set<String> present = new Set<String>();
        for (Account_KYC_Validation__mdt r : configured) {
            if (String.isNotBlank(r.Field_API_Name__c)) {
                present.add(r.Field_API_Name__c.trim().toLowerCase());
            }
        }
        List<Account_KYC_Validation__mdt> out = new List<Account_KYC_Validation__mdt>();
        for (String field : CONSOLE_PASSPORT_FIELDS) {
            if (present.contains(field.toLowerCase())) { continue; }
            out.add(new Account_KYC_Validation__mdt(
                Field_API_Name__c            = field,
                Field_Label__c               = AurelixIdentityRuleService.fieldLabel(OBJ_ACCOUNT, field),
                Object_API_Name__c           = OBJ_ACCOUNT,
                Record_Type_Developer_Name__c = RT_PERSON_ACCOUNT,
                ResidentType__c              = 'Resident,Non-Resident',
                Is_Active__c                 = true
            ));
        }
        return out;
    }

    /**
     * THE OPTION B DIFFERENCE. ResidentType__c is a comma-separated list of the residencies a
     * rule applies to. Blank means all. MODON's invocable ignores this field entirely, which is
     * why a non-resident is asked for an Emirates ID there and is not asked for one here.
     * An unknown residency matches only the universal rules.
     */
    @TestVisible
    private static Boolean appliesToResidency(Account_KYC_Validation__mdt r, String residency) {
        if (String.isBlank(r.ResidentType__c)) { return true; }
        if (String.isBlank(residency))         { return false; }
        for (String part : r.ResidentType__c.split(',')) {
            if (part.trim().equalsIgnoreCase(residency.trim())) { return true; }
        }
        return false;
    }

    /**
     * Read the target record with only the configured fields that actually exist on it. Field
     * names come from admin-controlled metadata, but they are still validated against the
     * describe before going anywhere near a query - an unknown or mistyped API name is skipped,
     * exactly as MODON's validator suppresses it, rather than throwing at the representative.
     */
    private static SObject readTarget(
        String objectApiName, Id recordId, List<Account_KYC_Validation__mdt> rules
    ) {
        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectApiName);
        if (sot == null) { return null; }
        Map<String, Schema.SObjectField> known = sot.getDescribe().fields.getMap();

        Set<String> fields = new Set<String>{ 'Id' };
        for (Account_KYC_Validation__mdt r : rules) {
            if (String.isBlank(r.Field_API_Name__c)) { continue; }
            String f = r.Field_API_Name__c.trim();
            if (known.containsKey(f.toLowerCase())) { fields.add(f); }
            // 4.5: a one-level path such as Account.Trade_License_Number__c, checked on the parent
            else if (isKnownPath(known, f)) { fields.add(f); }
        }

        String soql = 'SELECT ' + String.join(new List<String>(fields), ', ')
                    + ' FROM ' + objectApiName + ' WHERE Id = :recordId LIMIT 1';
        List<SObject> rows = Database.query(soql);
        return rows.isEmpty() ? null : rows[0];
    }

    /* ══════════════════════════════════════════════════════════════════════════════
     * 2.0 - THE MANUAL SUBMISSION. MODON's own controller does the work.
     * ══════════════════════════════════════════════════════════════════════════════ */

    /**
     * MODON's configured reasons, read off Account.KYC_Manual_Reason__c. The console offers no
     * reason of its own, so a reason added in Setup appears here without a deployment.
     */
    @TestVisible
    private static List<OptionDTO> manualReasonOptions() {
        List<OptionDTO> options = new List<OptionDTO>();
        Schema.DescribeFieldResult f = Account.KYC_Manual_Reason__c.getDescribe();
        for (Schema.PicklistEntry entry : f.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new OptionDTO(entry.getLabel(), entry.getValue()));
            }
        }
        return options;
    }

    /**
     * The files already on the buyer's Account that could serve as the supporting attachment.
     * Straight delegation to ManualKYCController.getAvailableKYCFiles - the quick action's own
     * list, so the rep sees exactly what an approver will.
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getManualKycFiles(Id opportunityId) {
        try {
            /* 4.11 - the record the request goes on: the POA Contact for a company */
            Id accountId = manualKycSubjectFor(opportunityId);
            if (accountId == null) {
                return new List<Map<String, String>>();
            }
            return ManualKYCController.getAvailableKYCFiles(accountId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * A freshly uploaded file only appears in the list above once it carries MODON's
     * "Manual KYC - " title convention, which is what their renameUploadedFile does. Wrapped
     * rather than reimplemented so the naming stays theirs.
     */
    @AuraEnabled
    public static Map<String, String> nameUploadedFile(Id documentId) {
        if (documentId == null) {
            return new Map<String, String>();
        }
        try {
            return ManualKYCController.renameUploadedFile(documentId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Submit the buyer for manual KYC approval.
     *
     * Reason and comment are mandatory; the supporting file is optional since 4.0 (the internal
     * app relaxed it on 17 Sep 2026 and MODON's submitForApproval accepts a null document Id).
     * Checked here as well as in the UI because a disabled button is a hint. For an organisation
     * the subject is the POA Contact (4.6) and never the company Account (4.11).
     *
     * The submission itself is MODON's: ManualKYCController.submitForApproval writes the reason
     * and comment, renames the chosen file and enters the Submit_for_Manual_KYC approval
     * process. None of that is reimplemented here.
     */
    @AuraEnabled
    public static String submitManualKyc(
        Id opportunityId, String reason, String comment, Id documentId
    ) {
        /* 4.6: the POA contact for a company, the account for a person. MODON's controller reads
           the record type and enters the matching approval process. */
        Id subjectId = manualKycSubjectFor(opportunityId);
        if (subjectId == null) {
            throw new AuraHandledException(isCompanyBooking(opportunityId)
                ? NO_COMPANY_SUBJECT
                : 'This booking has no customer account, so manual KYC cannot be submitted.');
        }
        return submitFor(subjectId, reason, comment, documentId);
    }

    /** 4.14: the checks and MODON's submission, for the buyer's subject or a joint owner's Account. */
    private static String submitFor(Id subjectId, String reason, String comment, Id documentId) {
        if (REASON_REQUIRED && String.isBlank(reason)) {
            throw new AuraHandledException('Choose the reason for manual KYC.');
        }
        if (COMMENT_REQUIRED && String.isBlank(comment)) {
            throw new AuraHandledException('Add a comment explaining the manual KYC.');
        }
        if (ATTACHMENT_REQUIRED && documentId == null) {
            throw new AuraHandledException('Attach the supporting document before submitting.');
        }
        try {
            ManualKYCController.submitForApproval(subjectId, reason, comment, documentId);
            return 'Submitted for manual KYC approval.';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════════════════════════════
     * 4.14 - THE JOINT OWNER'S MANUAL KYC ROUTE (28 Sep 2026).
     *
     * MODON's JointOwnerTriggerHelper refuses a joint owner whose KYC is not complete, and accepts
     * Manual_KYC_Approval__c = 'Approved' on the person's Account as the buyer's gate does. The Sales
     * App's manual route for such a person is the person Account's own "Submit for Manual KYC" and
     * "Update KYC" (Account_Record_Page3; not on the page Sales Management reps get). These entry
     * points give the console's Add Joint Owner drawer the buyer's route for one person: the same
     * evaluation, the same MODON submission and approval process on their Account, the same trail,
     * outcome and generation gate. Who may use them is SalesConsoleJointOwnerService.partyProblem's
     * answer: a person already on this booking, or one the rep could add to it now. Persons only:
     * a company joint owner's KYC is its Power of Attorney's and is not offered here.
     * ══════════════════════════════════════════════════════════════════════════════ */

    /** The joint owner's Account once partyProblem allows it; refused with its sentence otherwise. */
    private static Account partyFor(Id opportunityId, Id accountId) {
        String problem = SalesConsoleJointOwnerService.partyProblem(opportunityId, accountId);
        if (problem != null) {
            throw refused(problem);
        }
        List<Account> accs = [
            SELECT Id, Name, IsPersonAccount, PersonContactId, UAE_Resident_Status__pc
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
        if (accs.isEmpty() || accs[0].PersonContactId == null) {
            throw refused('That person could no longer be found.');
        }
        return accs[0];
    }

    /** 4.14: evaluate, for one joint owner. */
    private static ManualKycStateDTO partyState(Account party) {
        ManualKycStateDTO dto = new ManualKycStateDTO();
        dto.customerType = 'Person';
        return evaluatePersonSubject(dto, party.Id, party.PersonContactId, party.Name,
            party.UAE_Resident_Status__pc);
    }

    /** 4.14: what manual KYC still needs for this joint owner. Never throws, as evaluate. */
    @AuraEnabled(cacheable=false)
    public static ManualKycStateDTO evaluateParty(Id opportunityId, Id accountId) {
        try {
            return partyState(partyFor(opportunityId, accountId));
        } catch (AuraHandledException e) {
            ManualKycStateDTO dto = new ManualKycStateDTO();
            dto.customerType = 'Person';
            dto.blockedReason = e.getMessage();
            return dto;
        }
    }

    /** 4.14: getManualKycFiles, for one joint owner's Account. */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> getPartyManualKycFiles(Id opportunityId, Id accountId) {
        Account party = partyFor(opportunityId, accountId);
        try {
            return ManualKYCController.getAvailableKYCFiles(party.Id);
        } catch (Exception e) {
            throw refused(e.getMessage());
        }
    }

    /** 4.14: submitManualKyc, for one joint owner: MODON's Account approval process on their Account. */
    @AuraEnabled
    public static String submitPartyManualKyc(
        Id opportunityId, Id accountId, String reason, String comment, Id documentId
    ) {
        Account party = partyFor(opportunityId, accountId);
        return submitFor(party.Id, reason, comment, documentId);
    }

    /** 4.14: getApprovalTrail, for one joint owner. */
    @AuraEnabled(cacheable=false)
    public static ApprovalTrailDTO getPartyApprovalTrail(Id opportunityId, Id accountId) {
        Account party = partyFor(opportunityId, accountId);
        return approvalTrailFor(party.Id);
    }

    /** 4.14: getManualOutcome, for one joint owner. Empty when they may not use the route. */
    @AuraEnabled(cacheable=false)
    public static ManualOutcomeDTO getPartyManualOutcome(Id opportunityId, Id accountId) {
        Account party;
        try {
            party = partyFor(opportunityId, accountId);
        } catch (AuraHandledException e) {
            return new ManualOutcomeDTO();
        }
        return outcomeFor(party.Id, party.Id, new OutcomeSource(opportunityId, party));
    }

    /**
     * 4.14: the joint owner's KYC form, on their own "KYC Form" row, through the same gate and render.
     * Not sent for signature from here (AurelixKycFormGenerator 1.5 says why); the answer says how.
     */
    @AuraEnabled
    public static String requestPartyKycFormGeneration(Id opportunityId, Id accountId) {
        Account party = partyFor(opportunityId, accountId);
        AurelixKycFormGenerator.ResultDTO r =
            AurelixKycFormGenerator.generateForParty(party.PersonContactId, party.Name);
        return r.message;
    }

    /** 4.14: a refusal whose message Apex (and a test) can read, not "Script-thrown exception". */
    private static AuraHandledException refused(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    /**
     * 4.6: whose manual KYC this is.
     *
     * A company's is its Power of Attorney contact (MODON's Contact process), which since 4.15 is the
     * booking's primary contact (a POA row only when none is set); a person's is their Account,
     * as before. AurelixPoaResolver answers null for a person buyer, so one call decides both.
     */
    @TestVisible
    private static Id manualKycSubjectFor(Id opportunityId) {
        /* 4.15 - the primary contact for a company (the POA row only when none is set) */
        Id poaContactId = AurelixPoaResolver.bookingSubjectForOpportunity(opportunityId);
        if (poaContactId != null) {
            return poaContactId;
        }
        /* 4.11 - a company with no subject (4.15: neither a primary contact nor a POA row). Its own
           Account is never one: MODON's gate does not read an approval there. */
        if (isCompanyBooking(opportunityId)) {
            return null;
        }
        return buyerAccountFor(opportunityId);
    }

    /** 4.11 - true when the booking's buyer is a company (not a person account). */
    @TestVisible
    private static Boolean isCompanyBooking(Id opportunityId) {
        if (opportunityId == null) {
            return false;
        }
        for (Opportunity o : [SELECT Account.IsPersonAccount FROM Opportunity
                              WHERE Id = :opportunityId AND AccountId != null LIMIT 1]) {
            return o.Account.IsPersonAccount != true;
        }
        return false;
    }

    /** True for a Contact id, which is how the company route is told from the person one. */
    private static Boolean isContactSubject(Id subjectId) {
        return subjectId != null && subjectId.getSobjectType() == Contact.SObjectType;
    }

    /** 4.6: Manual_KYC_Approval__c from whichever record carries it. */
    private static String approvalStatusOf(Id subjectId) {
        if (subjectId == null) {
            return null;
        }
        if (isContactSubject(subjectId)) {
            for (Contact c : [SELECT Manual_KYC_Approval__c FROM Contact WHERE Id = :subjectId LIMIT 1]) {
                return c.Manual_KYC_Approval__c;
            }
            return null;
        }
        for (Account a : [SELECT Manual_KYC_Approval__c FROM Account WHERE Id = :subjectId LIMIT 1]) {
            return a.Manual_KYC_Approval__c;
        }
        return null;
    }

    /** The buyer Account behind an Opportunity, via its primary contact. */
    @TestVisible
    private static Id buyerAccountFor(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        List<Opportunity> opps = [
            SELECT Id, AccountId, PrimaryContact__r.AccountId
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty()) {
            return null;
        }
        Id viaContact = opps[0].PrimaryContact__r != null
            ? opps[0].PrimaryContact__r.AccountId : null;
        return viaContact != null ? viaContact : opps[0].AccountId;
    }

    /* ══════════════════════════════════════════════════════════════════════════════
     * 3.0 - AFTER APPROVAL: capture -> generate -> sign -> re-evaluate.
     * ══════════════════════════════════════════════════════════════════════════════ */

    /** Where a manual KYC has got to, and therefore what the console may offer next. */
    public class ManualOutcomeDTO {
        /** Account.Manual_KYC_Approval__c verbatim. */
        @AuraEnabled public String approvalStatus;
        @AuraEnabled public Boolean pending  = false;
        @AuraEnabled public Boolean approved = false;
        @AuraEnabled public Boolean rejected = false;
        /** Approved is what unlocks Update KYC - nothing before it. */
        @AuraEnabled public Boolean canUpdateKyc = false;
        /** The Option B verdict: may the form be generated yet? */
        @AuraEnabled public Boolean canGenerate = false;
        /** 4.7 - FIELD labels only. These are the ones Update KYC can fill. */
        @AuraEnabled public List<String> missingFields = new List<String>();
        /** 4.7 - identity documents with no file yet. These are uploaded, not typed. */
        @AuraEnabled public List<String> missingFiles = new List<String>();
        /** Generation and signature, read off the Documents__c rows. */
        @AuraEnabled public Boolean generationRequested = false;
        @AuraEnabled public String documentStatus;
        /**
         * 4.8 - the PDF itself exists: the row has reached MODON's Generated status. Requested is
         * only the ask, and nothing clears that flag, so the two are not the same state.
         */
        @AuraEnabled public Boolean formGenerated = false;
        /**
         * 4.9 - the last attempt to produce the form failed: Document_Status__c is Error, and no file
         * is on the row. MODON's logError and commitOutcomes are the only writers of that value.
         */
        @AuraEnabled public Boolean formFailed = false;
        /**
         * 4.9 - the row carries a status this console does not know. Never silently reported as a
         * request: the panel names the value so a representative can say what the record reads.
         */
        @AuraEnabled public Boolean formStatusUnknown = false;
        /**
         * 4.10 - the failed attempt may be made again: formFailed AND the gate permits a request.
         * False while anything is still missing, so the console never offers a retry that would be
         * refused; the missing list is the route forward there.
         */
        @AuraEnabled public Boolean formRetryable = false;
        /** 4.17 - the gate's generationInFlight: the only state in which a new request is refused. */
        @AuraEnabled public Boolean generationInFlight = false;
        /** 4.17 - a signed form filed in the CURRENT round (AurelixKycDocumentService.currentRoundStart). */
        @AuraEnabled public Boolean signedReceived = false;
        /**
         * 3.1 - the ContentDocument behind the signed form, so the console can offer to open it.
         * loadsignedkycform was re-inspected and NOT reused: it reads its record id from
         * CurrentPageReference.state.id and exposes no @api recordId, so embedded as a child it
         * would resolve nothing, and its Apex (CustomerKYCHandler) is not granted to the console
         * permission set. Option B - show the file the console already knows about.
         */
        @AuraEnabled public Id signedFileId;
        /**
         * 4.18 - a signed form from an earlier round, still on file, when none is filed this round.
         * MODON's booking check still accepts it, so the panel keeps it reachable.
         */
        @AuraEnabled public Id earlierSignedFileId;
        @AuraEnabled public Id accountId;
        /** 4.0 - 'Person' or 'Organisation'. */
        @AuraEnabled public String customerType;
        /** 4.0 - what Update KYC opens on: the person's Account, or the POA Contact. */
        @AuraEnabled public Id subjectId;
        @AuraEnabled public String subjectName;
        /** 4.0 - B8: the generation gate's own verdict and sentence. */
        @AuraEnabled public Boolean generationConfigured = false;
        @AuraEnabled public String generationBlockedReason;
        /** 4.0 - persons only. 4.13: a company's primary contact too. */
        @AuraEnabled public Boolean generationOffered = false;
        /** 4.3 - a rejection's date, approver and comment, read off the request itself. */
        @AuraEnabled public Datetime rejectedAt;
        @AuraEnabled public String rejectedBy;
        @AuraEnabled public String rejectionComment;
    }

    /**
     * The post-approval position for this booking. Read only: it decides what to OFFER, never
     * what the customer's KYC verdict is - that stays AurelixKycEligibilityService's alone.
     */
    @AuraEnabled(cacheable=false)
    public static ManualOutcomeDTO getManualOutcome(Id opportunityId) {
        Id accountId = buyerAccountFor(opportunityId);
        if (accountId == null) {
            return new ManualOutcomeDTO();
        }
        // 4.6: the POA contact's approval for a company, the account's for a person
        Id subjectId = manualKycSubjectFor(opportunityId);
        return outcomeFor(accountId, subjectId, new OutcomeSource(opportunityId, null));
    }

    /**
     * 4.14: where the two routes differ inside the outcome: the booking's buyer, or one joint owner's
     * own Account and contact. Everything else in outcomeFor is shared.
     */
    private class OutcomeSource {
        Id opportunityId;
        Account party;
        OutcomeSource(Id opportunityId, Account party) {
            this.opportunityId = opportunityId;
            this.party = party;
        }
        ManualKycStateDTO state() {
            return party == null ? evaluate(opportunityId) : partyState(party);
        }
        AurelixKycGenerationGate.GateDTO gate() {
            return party == null
                ? AurelixKycGenerationGate.check(opportunityId)
                : AurelixKycGenerationGate.checkContact(party.PersonContactId);
        }
        Id contactId() {
            return party == null ? subjectContactFor(opportunityId) : party.PersonContactId;
        }
    }

    /** 4.14: the body getManualOutcome always had, for either route. */
    private static ManualOutcomeDTO outcomeFor(Id accountId, Id subjectId, OutcomeSource src) {
        ManualOutcomeDTO out = new ManualOutcomeDTO();
        out.accountId = accountId;
        out.approvalStatus = approvalStatusOf(subjectId);
        String s = out.approvalStatus == null ? '' : out.approvalStatus.trim();
        out.approved = s.equalsIgnoreCase('Approved');
        out.rejected = s.equalsIgnoreCase('Rejected');
        out.pending  = s.equalsIgnoreCase('Submitted') || s.equalsIgnoreCase('Pending Approval');
        /* Update KYC belongs to an APPROVED manual route only. A pending one is still with
           Sales Operations and a rejected one has no route forward from this screen. */
        out.canUpdateKyc = out.approved;

        /* 4.3 - who rejected it, when, and why */
        if (out.rejected) {
            try {
                ApprovalTrailDTO trail = approvalTrailFor(subjectId);
                if (trail.requestStatus == 'Rejected') {
                    out.rejectedAt       = trail.decidedAt;
                    out.rejectedBy       = trail.decidedBy;
                    out.rejectionComment = trail.comment;
                }
            } catch (Exception e) {
                /* 4.4 - the plain "not approved" sentence stands */
            }
        }

        /* 4.0 - who this is about, and whether generation is even a question */
        ManualKycStateDTO state = src.state();
        out.customerType = state == null ? null : state.customerType;
        out.subjectId    = state == null ? null : state.subjectId;
        out.subjectName  = state == null ? null : state.subjectName;
        /* 4.13 - a person or a company's primary contact, as the Sales App offers it */
        AurelixKycGenerationGate.GateDTO gate = src.gate();
        out.generationOffered = gate.applicable == true;

        if (out.generationOffered) {
            /* B8 - Generate follows the gate; 4.13: the gate is MODON's validator */
            out.canGenerate             = gate.canGenerate == true;
            /* 4.7 - the two kinds, kept apart all the way to the screen */
            out.missingFields           = gate.missingFields;
            out.missingFiles            = gate.missingFiles;
            out.generationConfigured    = gate.configured == true;
            out.generationBlockedReason = gate.blockedReason;
            out.generationRequested     = gate.generationRequested == true;
            out.generationInFlight      = gate.generationInFlight == true;
            out.documentStatus          = gate.documentStatus;
            /* 4.9 - classify the row once, here, so the screen never has to match on a string
               4.17 - a file on the row counts as this KYC round's form only when filed since it began */
            Id formContact = src.contactId();
            applyFormState(out, formFiledThisRound(gate, formContact), gate.documentFilePresent == true);
            applySignedState(out, formContact);
        } else {
            out.canGenerate   = false;
            out.missingFields = state == null ? new List<String>() : state.missingFields;
        }
        return out;
    }

    /* ══════════════════════════════════════════════════════════════════════════════
     * 4.9 - DOES THE KYC FORM EXIST?
     *
     * MODON's Documents__c.Document_Status__c, read off the field on 24 Sep 2026, is a RESTRICTED
     * picklist with exactly these four active values and no others:
     *
     *   Generated  the PDF was produced. DocumentAutoGenerateService writes it once Drawloop has
     *              returned a PDF and the file is stored, our AurelixKycFormGenerator writes the
     *              same value, and MODON's DocumentTriggerHelper raises the DocuSign envelope on
     *              the transition into it. The form EXISTS.
     *   Sent       downstream of generation: nothing can be sent for signature that was not
     *              produced first. The form EXISTS. Shown exactly like Generated, because to a
     *              representative both mean "waiting for the signed form".
     *   Error      the render or the callout failed; Document_Error_Message__c carries the reason.
     *              The form does NOT exist, and this is its own state, not a pending request.
     *   Pending    the row's pre-generation value, before anything has been produced. The form
     *              does NOT exist, and "requested" is the honest reading.
     *
     * Nothing deployed writes Pending or Sent: across all 1935 Apex classes and all 252 Flows in
     * the org, only Generated and Error are written. The vocabulary is therefore MODON's to change,
     * which is why an unrecognised value is reported as unrecognised and never assumed to be a
     * request.
     *
     * The status word is not the test, though. The PDF's existence is a FILE on the "KYC Form"
     * row, which is true however the row came to hold it, and that outranks every word above.
     * ══════════════════════════════════════════════════════════════════════════════ */

    /** Every value the field may hold, lower case. Anything else is unrecognised by definition. */
    @TestVisible
    private static final Set<String> DOC_STATUS_KNOWN = new Set<String>{
        'pending', 'sent', 'error', 'generated'
    };
    @TestVisible
    private static final String DOC_STATUS_SENT  = 'Sent';
    /* 4.10 - one spelling between the gate and here. */
    @TestVisible
    private static final String DOC_STATUS_ERROR = AurelixKycGenerationGate.STATUS_ERROR;

    /**
     * 4.9 - sets formGenerated, formFailed and formStatusUnknown from the one row. Exactly one of
     * the three can be true, and all three false means the form has simply not been produced yet.
     * 4.10 - and formRetryable, which is formFailed narrowed by the gate's own verdict. canGenerate
     * is already on the DTO when this runs, so the two are decided in one place and cannot disagree.
     */
    @TestVisible
    private static void applyFormState(ManualOutcomeDTO out, Boolean fileOnRow) {
        applyFormState(out, fileOnRow, fileOnRow);
    }

    /**
     * 4.17 - fileThisRound: a file filed this KYC round; anyFile: any file. The status word counts only
     * on a row with no file, since it stays Generated through later rounds.
     */
    @TestVisible
    private static void applyFormState(ManualOutcomeDTO out, Boolean fileThisRound, Boolean anyFile) {
        String ds = out.documentStatus == null ? '' : out.documentStatus.trim();

        /* the file is the ground truth; the two words that also mean produced back it up */
        out.formGenerated = fileThisRound == true
            || (anyFile != true
                && (ds.equalsIgnoreCase(AurelixKycFormGenerator.STATUS_GENERATED)
                    || ds.equalsIgnoreCase(DOC_STATUS_SENT)));
        if (out.formGenerated) {
            return;
        }
        out.formFailed = ds.equalsIgnoreCase(DOC_STATUS_ERROR);
        if (out.formFailed) {
            /* 4.10 - offered again only where the gate would actually let it run */
            out.formRetryable = out.canGenerate == true;
            return;
        }
        /* Pending, or blank, leaves the request flag to speak. Anything else is named, not guessed. */
        out.formStatusUnknown = ds != '' && !DOC_STATUS_KNOWN.contains(ds.toLowerCase());
    }

    /**
     * 4.17 - the "KYC Form" row holds a file filed in the current KYC round (the manual request or the
     * completion date, AurelixKycDocumentService.kycRoundStart). Round unknown: any file counts.
     */
    private static Boolean formFiledThisRound(AurelixKycGenerationGate.GateDTO gate, Id contactId) {
        if (gate == null || gate.documentFilePresent != true || gate.documentId == null) {
            return false;
        }
        Datetime filed = AurelixKycDocumentService.latestFilingOn(new Set<Id>{ gate.documentId });
        if (filed == null) {
            /* the file sits on another "KYC Form" row of the contact: judged as before */
            return true;
        }
        Datetime since = AurelixKycDocumentService.kycRoundStart(contactId);
        return since == null || filed >= since;
    }

    /* ══════════════════════════════════════════════════════════════════════════════
     * 4.3 - THE APPROVAL REQUEST ITSELF.
     * ══════════════════════════════════════════════════════════════════════════════ */

    @TestVisible
    private static final String MANUAL_KYC_PROCESS = 'Submit_for_Manual_KYC';
    /* 4.6 - MODON's Contact process, for a company's Power of Attorney (added 21 Sep). */
    private static final String MANUAL_KYC_PROCESS_CONTACT = 'Submit_for_Manual_KYC_Contact';

    /** Where the latest manual-KYC request stands, from its own record. */
    public class ApprovalTrailDTO {
        /** ProcessInstance.Status of the latest request: Pending, Approved, Rejected, Removed. */
        @AuraEnabled public String requestStatus;
        @AuraEnabled public Datetime submittedAt;
        /** A request is waiting on someone. */
        @AuraEnabled public Boolean live = false;
        /** Who a live request waits on. */
        @AuraEnabled public List<String> approvers = new List<String>();
        /** The status says pending, but no request is waiting: recalled, or never entered. */
        @AuraEnabled public Boolean withdrawn = false;
        /** When, and by whom, the latest request was withdrawn, approved or rejected. */
        @AuraEnabled public Datetime decidedAt;
        @AuraEnabled public String decidedBy;
        /** The comment left with that decision. */
        @AuraEnabled public String comment;
    }

    /** One step of a request, as ProcessInstance.StepsAndWorkitems reports it. */
    @TestVisible
    private class TrailStep {
        public String status;
        public String actor;
        public String comments;
        public Datetime at;
        public TrailStep(String status, String actor, String comments, Datetime at) {
            this.status   = status;
            this.actor    = actor;
            this.comments = comments;
            this.at       = at;
        }
    }

    /** The KYC panel's reading of the request: sent when, waiting on whom, or withdrawn. */
    @AuraEnabled(cacheable=false)
    public static ApprovalTrailDTO getApprovalTrail(Id opportunityId) {
        // 4.6: the request lives on the POA contact for a company
        Id subjectId = manualKycSubjectFor(opportunityId);
        if (subjectId == null) {
            return new ApprovalTrailDTO();
        }
        return approvalTrailFor(subjectId);
    }

    private static ApprovalTrailDTO approvalTrailFor(Id subjectId) {
        String fieldStatus = approvalStatusOf(subjectId);
        /* 4.4 - TargetObjectId is the only filter a representative may put on ProcessInstance */
        List<ProcessInstance> requests = [
            SELECT Id, Status, CreatedDate, ProcessDefinitionId,
                   (SELECT StepStatus, Actor.Name, Comments, CreatedDate
                    FROM StepsAndWorkitems
                    ORDER BY CreatedDate DESC)
            FROM ProcessInstance
            WHERE TargetObjectId = :subjectId
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
        Id manualKycProcess = manualKycProcessId(isContactSubject(subjectId));
        if (manualKycProcess == null) {
            /* no way to tell the manual-KYC request from the account's other approvals: say
               nothing rather than guess - a pending request must never read as withdrawn */
            throw new AuraHandledException('The manual KYC approval process could not be read.');
        }
        ProcessInstance request;
        for (ProcessInstance pi : requests) {
            if (pi.ProcessDefinitionId == manualKycProcess) {
                request = pi;
                break;
            }
        }
        if (request == null) {
            return readTrail(fieldStatus, null, null, new List<TrailStep>());
        }
        List<TrailStep> steps = new List<TrailStep>();
        for (ProcessInstanceHistory h : request.StepsAndWorkitems) {
            steps.add(new TrailStep(
                h.StepStatus, h.Actor == null ? null : h.Actor.Name, h.Comments, h.CreatedDate));
        }
        return readTrail(fieldStatus, request.Status, request.CreatedDate, steps);
    }

    /* 4.4 - the Submit_for_Manual_KYC definition's Id, once per transaction. ProcessDefinition is
       read by name here; the relationship FILTER on ProcessInstance is what a representative is refused. */
    private static Map<String, Id> manualKycProcessIdCache = new Map<String, Id>();
    /* 4.6 - which process: the Account one, or MODON's Contact one for a company's POA. */
    private static Id manualKycProcessId(Boolean forContact) {
        String objectName = forContact == true ? 'Contact' : 'Account';
        String name = forContact == true ? MANUAL_KYC_PROCESS_CONTACT : MANUAL_KYC_PROCESS;
        if (!manualKycProcessIdCache.containsKey(objectName)) {
            Id found;
            try {
                for (ProcessDefinition d : [
                    SELECT Id FROM ProcessDefinition
                    WHERE DeveloperName = :name AND TableEnumOrId = :objectName
                    LIMIT 1
                ]) {
                    found = d.Id;
                }
            } catch (Exception e) {
                found = null;
            }
            manualKycProcessIdCache.put(objectName, found);
        }
        return manualKycProcessIdCache.get(objectName);
    }

    /**
     * Pure: the trail from the account's status field and the latest request's steps, newest
     * first. A request that is not Pending while the field still says pending is WITHDRAWN -
     * the field is all MODON's recall leaves behind.
     */
    @TestVisible
    private static ApprovalTrailDTO readTrail(
            String fieldStatus, String requestStatus, Datetime submittedAt, List<TrailStep> steps) {
        ApprovalTrailDTO out = new ApprovalTrailDTO();
        out.requestStatus = requestStatus;
        out.submittedAt   = submittedAt;
        String f = fieldStatus == null ? '' : fieldStatus.trim();
        Boolean fieldPending = f.equalsIgnoreCase('Submitted') || f.equalsIgnoreCase('Pending Approval');

        out.live = requestStatus == 'Pending';
        if (out.live) {
            for (TrailStep s : steps) {
                if (s.status == 'Pending' && String.isNotBlank(s.actor)
                        && !out.approvers.contains(s.actor)) {
                    out.approvers.add(s.actor);
                }
            }
            return out;
        }

        out.withdrawn = fieldPending;
        for (TrailStep s : steps) {
            if (s.status == 'Removed' || s.status == 'Approved' || s.status == 'Rejected') {
                out.decidedAt = s.at;
                out.decidedBy = s.actor;
                out.comment   = String.isBlank(s.comments) ? null : s.comments.trim();
                break;
            }
        }
        return out;
    }

    /** The buyer's contact - where the "KYC Form" rows live. Null for a company. */
    @TestVisible
    private static Id subjectContactFor(Id opportunityId) {
        for (Opportunity o : [
            SELECT PrimaryContact__c, Account.IsPersonAccount, Account.PersonContactId
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            if (o.Account != null && o.Account.IsPersonAccount == true && o.Account.PersonContactId != null) {
                return o.Account.PersonContactId;
            }
            return o.PrimaryContact__c;
        }
        return null;
    }

    /**
     * 4.2 - file the signed copy where the gate looks for it, when DocuSign's write-back left it
     * on the "KYC Form" row. Returns true when a link was made. Never throws: a reconcile that
     * fails leaves the state as it was and the panel still renders.
     * 4.16 - a renewal too: a signed row whose files all predate the current KYC round gets this
     * round's signed copy beside them (never an older or an unsigned file; nothing is removed).
     */
    @TestVisible
    private static Boolean fileSignedCopy(Id contactId) {
        try {
            Documents__c target;
            for (Documents__c t : [
                SELECT Id FROM Documents__c
                WHERE PrimaryContact__c = :contactId AND Name = :DOC_KYC_SIGNED ORDER BY CreatedDate DESC LIMIT 1
            ]) { target = t; }
            if (target == null) { return false; }
            /* 4.16 - set only for a renewal: the copy must be filed after both */
            Datetime roundStart;
            Datetime rowFiled;
            if (![SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :target.Id LIMIT 1].isEmpty()) {
                /* already filed - by MODON's mover or by an earlier reconcile - unless every file on the
                   row was filed before the current KYC round began (the rule the files lock on) */
                rowFiled   = AurelixKycDocumentService.latestFilingOn(new Set<Id>{ target.Id });
                roundStart = AurelixKycDocumentService.currentRoundStart(contactId);
                if (rowFiled == null || roundStart == null || rowFiled >= roundStart) { return false; }
            }
            Boolean renewal = roundStart != null;
            List<Documents__c> forms = [
                SELECT Id, EnvelopID__c FROM Documents__c
                WHERE PrimaryContact__c = :contactId AND Name = :DOC_KYC_FORM AND EnvelopID__c != null
                ORDER BY CreatedDate DESC LIMIT 1
            ];
            if (forms.isEmpty()) { return false; }
            Documents__c form = forms[0];

            /* the files on the form row, newest first */
            List<ContentDocumentLink> links = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate
                FROM ContentDocumentLink WHERE LinkedEntityId = :form.Id
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            Datetime completedAt = envelopeCompletedAt(form.EnvelopID__c);
            if (renewal) {
                /* 4.16 - this round only: files after the round start and the row's own file. An envelope
                   completed before the round is last round's; only a certificate from this round counts. */
                List<ContentDocumentLink> thisRound = new List<ContentDocumentLink>();
                for (ContentDocumentLink l : links) {
                    Datetime created = l.ContentDocument.CreatedDate;
                    if (created != null && created >= roundStart && created > rowFiled) { thisRound.add(l); }
                }
                links = thisRound;
                if (completedAt != null && completedAt < roundStart) { completedAt = null; }
            }
            Boolean certificateSeen = false;
            for (ContentDocumentLink l : links) {
                if (l.ContentDocument.Title != null && l.ContentDocument.Title.startsWith('CertificateOfCompletion')) { certificateSeen = true; }
            }
            if (completedAt == null && !certificateSeen) { return false; }

            /* the signed copy: the newest "KYC Form Manual…" file written after completion (or,
               without a readable envelope status, the newest one that is not the certificate and
               is not the oldest - the original render) */
            ContentDocumentLink signed;
            for (ContentDocumentLink l : links) {
                String title = l.ContentDocument.Title == null ? '' : l.ContentDocument.Title;
                if (title.startsWith('CertificateOfCompletion')) { continue; }
                if (completedAt != null) {
                    if (l.ContentDocument.CreatedDate >= completedAt.addMinutes(-2)) { signed = l; break; }
                } else if (links.size() >= 3 && l != links[links.size() - 1]) {
                    signed = l; break;
                }
            }
            if (signed == null) { return false; }
            insert new ContentDocumentLink(
                LinkedEntityId = target.Id, ContentDocumentId = signed.ContentDocumentId,
                ShareType = 'V', Visibility = 'AllUsers');
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    /** DocuSign's own completion time for an envelope, from the installed package's status record; null when unknown. */
    @TestVisible
    private static Datetime envelopeCompletedAt(String docuSignId) {
        if (String.isBlank(docuSignId)) { return null; }
        try {
            for (SObject e : Database.query(
                'SELECT dfsle__Status__c, dfsle__Completed__c FROM dfsle__EnvelopeStatus__c '
                + 'WHERE dfsle__DocuSignId__c = :docuSignId ORDER BY CreatedDate DESC LIMIT 1')) {
                if (String.valueOf(e.get('dfsle__Status__c')) == 'Completed') {
                    Datetime c = (Datetime) e.get('dfsle__Completed__c');
                    return c == null ? Datetime.now() : c;
                }
            }
        } catch (Exception ignored) {
            /* the package or its object may be out of reach for a site user - the caller falls back */
        }
        return null;
    }

    /**
     * The signed copy, read off the "KYC Form - Signed" row on the buyer's CONTACT - the row
     * MODON's moveManualKYCFormToSigned files the DocuSign _completed.pdf onto (4.0), or that
     * fileSignedCopy links the write-back to (4.2).
     */
    private static void applySignedState(ManualOutcomeDTO out, Id contactId) {
        if (contactId == null) { return; }
        fileSignedCopy(contactId);
        /* 4.17 - only a signed form from the current round counts (round start read once, when needed) */
        Datetime since;
        Boolean sinceRead = false;
        Datetime newestFiling;
        Id newestRow;
        /* 4.18 - the newest signed form from an earlier round, still on file */
        Datetime earlierFiling;
        Id earlierRow;
        for (Documents__c signed : [
            SELECT Id FROM Documents__c
            WHERE PrimaryContact__c = :contactId AND Name = :DOC_KYC_SIGNED
            ORDER BY CreatedDate
        ]) {
            /* "signed" means a FILE came back, not merely that the row exists - the same
               file-presence test the eligibility service applies to every other document. */
            SignedFileContext files = new SignedFileContext();
            if (!files.hasFile(signed.Id)) { continue; }
            Datetime filed = AurelixKycDocumentService.latestFilingOn(new Set<Id>{ signed.Id });
            if (!sinceRead) {
                since = AurelixKycDocumentService.currentRoundStart(contactId);
                sinceRead = true;
            }
            if (since != null && filed != null && filed < since) {
                if (earlierRow == null || earlierFiling == null || filed > earlierFiling) {
                    earlierRow = signed.Id;
                    earlierFiling = filed;
                }
                continue;
            }
            if (newestRow == null || (filed != null && (newestFiling == null || filed > newestFiling))) {
                newestRow = signed.Id;
                newestFiling = filed;
            }
        }
        if (newestRow != null) {
            out.signedReceived = true;
            out.signedFileId   = new SignedFileContext().fileIdFor(newestRow);
        } else if (earlierRow != null) {
            out.earlierSignedFileId = new SignedFileContext().fileIdFor(earlierRow);
        }
    }

    /**
     * File presence, WITHOUT SHARING and deliberately so: a signed KYC uploaded by somebody
     * else - Sales Operations, the DocuSign callback - must still count. The same rule the
     * eligibility service applies to every other document.
     */
    private without sharing class SignedFileContext {
        /** The newest ContentDocument on the row, for a view link. Null when there is none.
            4.16 - newest by the file's own date first (a renewal leaves last round's file beside it). */
        Id fileIdFor(Id documentId) {
            if (documentId == null) { return null; }
            for (ContentDocumentLink l : [
                SELECT ContentDocumentId FROM ContentDocumentLink
                WHERE LinkedEntityId = :documentId
                ORDER BY ContentDocument.ContentModifiedDate DESC, SystemModstamp DESC LIMIT 1
            ]) { return l.ContentDocumentId; }
            return null;
        }

        Boolean hasFile(Id documentId) {
            if (documentId == null) { return false; }
            if (![SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :documentId LIMIT 1].isEmpty()) {
                return true;
            }
            return ![SELECT Id FROM Attachment WHERE ParentId = :documentId LIMIT 1].isEmpty();
        }
    }

    /**
     * The capture form, exactly as MODON builds it. resolveContext and loadForm carry the whole
     * field engine - sections, picklists, dependent options, address handling, date rules - so
     * the console renders THEIR definition rather than a second, drifting copy of it.
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getCaptureForm(Id opportunityId) {
        Id accountId = buyerAccountFor(opportunityId);
        if (accountId == null) {
            throw new AuraHandledException('This booking has no customer account to capture against.');
        }
        /* 4.0 - a company's form opens on its POA Contact; MODON's resolveContext then returns the
           contact section, Contact Mailing, the company fields and Account Billing. */
        Id subjectId = captureSubjectFor(opportunityId, accountId);
        try {
            return new Map<String, Object>{
                'accountId' => accountId,
                'subjectId' => subjectId,
                'context'   => AccountKycController.resolveContext(subjectId),
                'form'      => AccountKycController.loadForm(subjectId)
            };
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Save the captured values through MODON's own saveForm, in its own payload shape
     * ({sourceRecordId, accountValues, contactValues}). Field mapping, address handling and
     * their validation semantics are preserved because it is their method doing the work.
     */
    @AuraEnabled
    public static String saveCaptureForm(
        Id opportunityId, String accountValuesJson, String contactValuesJson
    ) {
        Id accountId = buyerAccountFor(opportunityId);
        if (accountId == null) {
            throw new AuraHandledException('This booking has no customer account to save against.');
        }
        Map<String, Object> payload = new Map<String, Object>{
            'sourceRecordId' => String.valueOf(captureSubjectFor(opportunityId, accountId)),
            'accountValues'  => parseValues(accountValuesJson),
            'contactValues'  => parseValues(contactValuesJson)
        };
        try {
            return AccountKycController.saveForm(JSON.serialize(payload));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** 4.0 - the POA Contact for a company, the Account itself for a person. */
    @TestVisible
    private static Id captureSubjectFor(Id opportunityId, Id accountId) {
        /* 4.15 - the primary contact for a company (the POA row only when none is set) */
        Id poa = AurelixPoaResolver.bookingSubjectForOpportunity(opportunityId);
        return poa != null ? poa : accountId;
    }

    /* The parameter is NOT called `json`: Apex identifiers are case-insensitive, so a variable
       of that name shadows the JSON class and JSON.deserializeUntyped stops compiling. */
    private static Map<String, Object> parseValues(String raw) {
        if (String.isBlank(raw)) {
            return new Map<String, Object>();
        }
        return (Map<String, Object>) JSON.deserializeUntyped(raw);
    }

    /**
     * ASK FOR THE KYC FORM (4.1). The console renders on request through MODON's own Nintex
     * helper and status writes - see AurelixKycFormGenerator - because their trigger only
     * generates on insert, so the earlier flag-by-update route produced nothing.
     */
    @AuraEnabled
    public static String requestKycFormGeneration(Id opportunityId) {
        Id accountId = buyerAccountFor(opportunityId);
        if (accountId == null) {
            throw new AuraHandledException('This booking has no customer account.');
        }
        /* 4.1 - on request, through MODON's Nintex helper; the gate decides, the generator renders,
           stores and writes MODON's status. Refusals carry the gate's own sentence. */
        AurelixKycFormGenerator.ResultDTO r = AurelixKycFormGenerator.generate(opportunityId);
        return r.message;
    }

    /** Null when the field was skipped as unknown, which reads as "not satisfied". */
    private static Object readValue(SObject record, String fieldApiName) {
        if (record == null || String.isBlank(fieldApiName)) { return null; }
        try {
            String f = fieldApiName.trim();
            // 4.5: Account.Trade_License_Number__c and the like
            if (f.contains('.')) {
                SObject parent = record.getSObject(f.substringBefore('.'));
                return parent == null ? null : parent.get(f.substringAfter('.'));
            }
            return record.get(f);
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * 4.5: is "Relationship.Field" a real one-level path on this object? Both halves are checked
     * against the describe before the path goes into a query, as plain field names are.
     */
    private static Boolean isKnownPath(Map<String, Schema.SObjectField> known, String path) {
        if (!path.contains('.') || path.countMatches('.') != 1) { return false; }
        String rel = path.substringBefore('.');
        String field = path.substringAfter('.');
        for (Schema.SObjectField sf : known.values()) {
            Schema.DescribeFieldResult d = sf.getDescribe();
            if (d.getRelationshipName() != null && d.getRelationshipName().equalsIgnoreCase(rel)
                    && !d.getReferenceTo().isEmpty()) {
                return d.getReferenceTo()[0].getDescribe().fields.getMap().containsKey(field.toLowerCase());
            }
        }
        return false;
    }
}