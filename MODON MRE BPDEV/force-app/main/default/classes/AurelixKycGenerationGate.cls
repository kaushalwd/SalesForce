/**
 * AurelixKycGenerationGate - may the KYC form be generated for this buyer yet?
 *
 * Version  Author       Date         Detail
 * 2.3      Aurelix Dev  29 Sep 2026  The form may be generated again, as in the Sales App: "already requested" now
 *                                    only while a request is in flight (claimed, or awaiting its envelope, within
 *                                    IN_FLIGHT_MINUTES). 2.2 now drops only Occupation and Employer / Business Name.
 * 2.2      Aurelix Dev  29 Sep 2026  Console only, unlike the Sales App: a person's Occupation, Employer / Business
 *                                    Name or Other Source of Income is dropped from MODON's missing list when MODON's
 *                                    Update KYC form hides it. Remove once MODON makes those rows conditional.
 * 2.1      Aurelix Dev  28 Sep 2026  checkContact: the same gate for a contact named directly, so a joint owner's
 *                                    "KYC Form" row is checked exactly as a buyer's (the joint owner's manual KYC
 *                                    route, 28 Sep). check(opportunityId) only resolves the contact and
 *                                    calls it; nothing in the gate itself changed.
 * 2.0      Aurelix Dev  27 Sep 2026  THE SALES APP'S OWN CHECK, FOR PERSONS AND COMPANIES (27 Sep: the
 *                                    console must behave as MODON's Sales App does). The Sales App's "Genrate
 *                                    Document" button on a "KYC Form" row runs flow Genrate_Document, which
 *                                    checks one thing, AccountKYCValidationInvocable on that row, and then
 *                                    runs Nintex "KYC Form Manual". That validator is residency-aware since
 *                                    its 1.1 (21 Sep), handles a company's POA Contact since 1.4 (22 Sep,
 *                                    Parent_Record_Type__c), and lists every missing field in one sentence.
 *                                    So the gate now calls it on the row and reports its answer word for
 *                                    word. Gone, because the Sales App does not ask for them before
 *                                    generating: Option B, the PersonAccountFiledSet test (MODON's older
 *                                    generatekycform validator, no longer on the active page), gender, and
 *                                    the Passport and Emirates ID files (still required at booking, by
 *                                    checkKYCEligibility). A company is now applicable: its subject is the
 *                                    opportunity's primary contact, the person checkKYCEligibility reads
 *                                    and on whom MODON's Contact flow creates the "KYC Form" row once the
 *                                    manual KYC is approved. Kept, because they are the console's
 *                                    mechanics rather than rules: a package must be named, the row must
 *                                    exist, and a request is not repeated while it stands (1.5).
 * 1.5      Aurelix Dev  24 Sep 2026  A FAILED ATTEMPT WAS A DEAD END. The last refusal in the chain below,
 *                                    "The form has already been requested.", reads Auto_Generate_Document__c,
 *                                    which nothing ever clears - so a row whose render had failed could
 *                                    never be asked for again and the representative had no route back
 *                                    except someone with Salesforce access. A request that
 *                                    produced nothing is not an outstanding request, so lastAttemptFailed
 *                                    (Document_Status__c reads Error and no file is on the row) now excuses
 *                                    that one refusal and only that one. Nothing else moves: a row that is
 *                                    Pending, Generated, Sent, blank or carrying a word we do not know is
 *                                    judged exactly as in 1.4, and a row at Error that DOES hold its file
 *                                    is a produced form, so it stays refused. The render itself needs no
 *                                    reset: AurelixKycFormGenerator calls Nintex directly on every request
 *                                    (DrawloopHelper plus one HTTP GET), so a second ask is a second render,
 *                                    and MODON's own flag driven route is not involved - their
 *                                    DocumentAutoGenerateService is after insert only and its first gate is
 *                                    the template row's Auto_Generate_Document__c, false for both "KYC Form"
 *                                    rows in MODON_DEV_1 (read 24 Sep 2026).
 * 1.4      Aurelix Dev  24 Sep 2026  THE PRODUCED PDF IS A FILE, NOT A STATUS WORD. The console decided
 *                                    that a form existed from Document_Status__c alone, and only from the
 *                                    exact value 'Generated', so a "KYC Form" row that already carried its
 *                                    PDF still read "Form requested". The field is a
 *                                    restricted picklist of four values - Pending, Sent, Error, Generated,
 *                                    read off the field on 24 Sep 2026 - and MODON's only production
 *                                    writers, DocumentAutoGenerateService.commitOutcomes and logError,
 *                                    write just Generated and Error, so the word cannot be trusted to
 *                                    describe every row. documentFilePresent reports the ground truth
 *                                    instead: a file on the row. It is read in the same call as the
 *                                    identity proofs below, so the check costs no extra query.
 * 1.3      Aurelix Dev  24 Sep 2026  FIELDS AND FILES ARE NOT THE SAME THING TO A REPRESENTATIVE.
 *                                    The one `missing` list mixed field labels with identity
 *                                    documents dressed as "Passport (file)", and the console could
 *                                    only tell them apart by matching on that suffix - so it told the
 *                                    rep to complete a passport scan in Update KYC, where no file can
 *                                    be uploaded. The gate now reports the two kinds
 *                                    separately, missingFields and missingFiles, and each caller says
 *                                    the right thing about each. `missing` is unchanged: still the
 *                                    union, still in the same order, still with the "(file)" suffix,
 *                                    because blockedReason and AurelixKycFormGenerator's refusal read
 *                                    it and one sentence naming everything is right for a refusal.
 * 1.2      Aurelix Dev  18 Sep 2026  documentError / envelopeId on the DTO (MODON's
 *                                    Document_Error_Message__c and EnvelopID__c), so a failed
 *                                    render or DocuSign send can be seen and shown.
 * 1.1      Aurelix Dev  18 Sep 2026  "configured" now means a package is NAMED - on MODON's
 *                                    template row or on the console switch KYC_FORM_DOCGEN_PACKAGE
 *                                    (AurelixKycFormGenerator.packageName). The template row's own
 *                                    Auto_Generate_Document__c is deliberately NOT required: set,
 *                                    it would make DocumentsUtility fire Nintex for every new
 *                                    customer at row creation (SCW-121). Generation itself moved to
 *                                    AurelixKycFormGenerator, on request.
 * 1.0      Aurelix Dev  18 Sep 2026  MSC-177 (B8). ONE missing list, the union of every rule that
 *                                    can stop a generated form from being usable:
 *                                      1 Option B - AurelixManualKycService.evaluate: MODON's
 *                                        Account_KYC_Validation__mdt rows, residency-aware, plus
 *                                        the console's passport pair (B2).
 *                                      2 MODON's own generation validator's rule - the field set
 *                                        Account.PersonAccountFiledSet (names, birthdate, email,
 *                                        mobile, passport number, nationality, residency). The
 *                                        query is built by CustomerKYCHandler.queryByFieldSet;
 *                                        their areAnyFieldsEmpty returns after the FIRST gap, so
 *                                        the same blank test is applied here to every member of
 *                                        the same field set, and all of them are named.
 *                                      3 Gender identity, which the printed form carries.
 *                                      4 Identity proof on record: a Passport file, and for a
 *                                        Resident the Emirates ID front and back files.
 *                                    Plus two facts about the mechanics: is the "KYC Form"
 *                                    template row configured for Nintex (DocGen package and
 *                                    delivery option - MODON fills these; blank today), and does
 *                                    the buyer's contact carry a "KYC Form" row to raise the flag
 *                                    on. Generate stays off until every part is true.
 *                                    Persons only: corporate generation is hidden by decision.
 *
 * OWNERSHIP. Aurelix-owned. AccountKYCValidationInvocable, Account_KYC_Validation__mdt,
 * AccountKycController / accountkycform (2.2 mirrors their visibility rules, it does not call them),
 * Document_Master_Configuration__mdt and Documents__c are MODON's and are read or called, never changed.
 */
public with sharing class AurelixKycGenerationGate {

    public static final String TEMPLATE_OBJECT = 'PersonAccount';
    public static final String TEMPLATE_NAME   = 'KYC Form';
    /**
     * 1.5 - MODON's own word for a render that failed, on Documents__c.Document_Status__c. Held here
     * so the gate and AurelixManualKycService spell it once between them.
     */
    public static final String STATUS_ERROR   = 'Error';
    /* 2.3 - MODON's other two words on the same restricted picklist */
    public static final String STATUS_PENDING   = 'Pending';
    public static final String STATUS_GENERATED = 'Generated';
    /** 2.3 - the gate's own words for a request in flight (AurelixKycFormGenerator.ALREADY_REQUESTED too). */
    public static final String ALREADY_REQUESTED = 'The form has already been requested.';
    /** 2.3 - minutes a claimed or sending row counts as in flight; after that it is treated as stuck. */
    public static final Integer IN_FLIGHT_MINUTES = 5;

    public class GateDTO {
        /** 2.0 - false only when the booking has no buyer contact to generate for. */
        @AuraEnabled public Boolean applicable = false;
        @AuraEnabled public Boolean canGenerate = false;
        /** 2.0 - the fields MODON's validator names, in its order. */
        @AuraEnabled public List<String> missing = new List<String>();
        /**
         * 1.3 - the same requirements split by kind, because a field is filled in Update KYC and a
         * file is uploaded. Field labels only.
         */
        @AuraEnabled public List<String> missingFields = new List<String>();
        /** 1.3 - document names. 2.0: always empty, the Sales App asks for no file before generating. */
        @AuraEnabled public List<String> missingFiles = new List<String>();
        /** The Nintex package and delivery option are on the "KYC Form" template row. */
        @AuraEnabled public Boolean configured = false;
        @AuraEnabled public String notConfiguredReason;
        /** The "KYC Form" row on the buyer's contact, where the flag is raised. */
        @AuraEnabled public Id documentId;
        @AuraEnabled public String documentStatus;
        /**
         * 1.4 - a file is on the "KYC Form" row, which is the produced PDF itself. Kept separate from
         * documentStatus because the status word does not cover every way a row comes to hold its file.
         */
        @AuraEnabled public Boolean documentFilePresent = false;
        /** 1.2 - MODON's Document_Error_Message__c, so a failed render or send is visible. */
        @AuraEnabled public String documentError;
        @AuraEnabled public String envelopeId;
        @AuraEnabled public Boolean generationRequested = false;
        /**
         * 1.5 - the last attempt to produce the form failed and left nothing behind: the row reads
         * Error and carries no file. The ask was made, so generationRequested may well be true, but
         * there is nothing outstanding, which is why a fresh request is allowed below.
         */
        @AuraEnabled public Boolean lastAttemptFailed = false;
        /** 2.3 - a request is in flight (see inFlight): the only state that refuses a new request. */
        @AuraEnabled public Boolean generationInFlight = false;
        /** The one sentence that explains a disabled Generate; null when it may be offered. */
        @AuraEnabled public String blockedReason;
    }

    /** Tests set this to prove both branches without editing custom metadata. */
    @TestVisible
    private static Boolean templateConfiguredOverride;

    @AuraEnabled(cacheable=false)
    public static GateDTO check(Id opportunityId) {
        GateDTO g = new GateDTO();
        if (opportunityId == null) { return g; }

        List<Opportunity> opps = [
            SELECT Id, AccountId, PrimaryContact__c, Account.IsPersonAccount, Account.PersonContactId
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ];
        if (opps.isEmpty() || opps[0].AccountId == null) {
            return g;
        }
        Opportunity opp = opps[0];
        /* 2.0 - a person's own contact; for a company the primary contact (the POA) */
        Id contactId = opp.Account.IsPersonAccount == true && opp.Account.PersonContactId != null
            ? opp.Account.PersonContactId
            : opp.PrimaryContact__c;
        return checkContact(contactId);
    }

    /**
     * 2.1: the gate for one contact's "KYC Form" row: a person's own contact, or a company's primary
     * contact. Not @AuraEnabled: the console reaches it through AurelixManualKycService, which decides
     * whose contact it is.
     */
    public static GateDTO checkContact(Id contactId) {
        GateDTO g = new GateDTO();
        if (contactId == null) {
            return g;
        }
        g.applicable = true;

        /* the "KYC Form" row, where the Sales App's button lives */
        for (Documents__c d : [
            SELECT Id, Document_Status__c, Document_Error_Message__c, EnvelopID__c, Auto_Generate_Document__c,
                   Auto_Send_DocuSign_Email__c, LastModifiedDate
            FROM Documents__c
            WHERE PrimaryContact__c = :contactId AND Name = :TEMPLATE_NAME
            ORDER BY CreatedDate LIMIT 1
        ]) {
            g.documentId          = d.Id;
            g.documentStatus      = d.Document_Status__c;
            g.documentError       = d.Document_Error_Message__c;
            g.envelopeId          = d.EnvelopID__c;
            g.generationRequested = d.Auto_Generate_Document__c == true;
            /* 2.3 - the one state that still refuses a request */
            g.generationInFlight  = inFlight(d);
        }
        /* 1.4 - a file on the row is the produced PDF */
        g.documentFilePresent = AurelixKycDocumentService.namesWithFile(
            contactId, new List<String>{ AurelixKycDocumentService.DOC_KYC_FORM }
        ).contains(AurelixKycDocumentService.DOC_KYC_FORM);
        /* 1.5 - Error with the file already on the row is a produced form, not a failure */
        g.lastAttemptFailed = g.documentStatus != null
            && STATUS_ERROR.equalsIgnoreCase(g.documentStatus.trim())
            && g.documentFilePresent != true;

        /* 2.0 - MODON's validation on the row, as flow Genrate_Document runs it */
        String validationProblem = null;
        if (g.documentId != null) {
            ModonVerdict v = modonValidation(g.documentId);
            if (v.success != true) {
                if (v.missing.isEmpty()) {
                    validationProblem = v.message;
                } else {
                    /* 2.2 - drop only what MODON's own form hides from this buyer */
                    List<String> kept = withoutFieldsTheFormHides(g.documentId, v.missing);
                    Set<String> seen = new Set<String>();
                    for (String m : kept) { add(g, seen, m); }
                    if (kept.isEmpty()) {
                        validationProblem = null;
                    } else if (kept.size() == v.missing.size()) {
                        validationProblem = v.message;
                    } else {
                        validationProblem = MODON_MISSING_PREFIX + ' ' + String.join(kept, ', ');
                    }
                }
            }
        }

        /* the mechanics */
        g.configured = templateConfigured();
        if (!g.configured) {
            g.notConfiguredReason = 'Form generation is not configured yet.';
        }

        if (g.documentId == null) {
            g.blockedReason = 'No "' + TEMPLATE_NAME + '" document record exists for this customer yet.';
        } else if (String.isNotBlank(validationProblem)) {
            g.blockedReason = validationProblem;
        } else if (!g.configured) {
            g.blockedReason = g.notConfiguredReason;
        } else if (g.generationInFlight && !g.lastAttemptFailed) {
            /* 1.5 - a request that produced nothing is not an outstanding one.
               2.3 - nor is a finished one (the Sales App regenerates at will) */
            g.blockedReason = ALREADY_REQUESTED;
        }
        g.canGenerate = g.blockedReason == null;
        return g;
    }

    /* ══ 2.3 - a request on its way ═══════════════════════════════════════════════ */

    /**
     * 2.3 - a claimed request whose form has not reached the customer yet: the row is Pending and requested,
     * or Generated, requested and flagged for MODON's send with no envelope id and no error. No time limit:
     * the documents lock treats such a row as the start of a new round.
     */
    public static Boolean generationUnderway(Documents__c row) {
        if (row == null || row.Auto_Generate_Document__c != true) {
            return false;
        }
        String status = row.Document_Status__c == null ? '' : row.Document_Status__c.trim();
        if (STATUS_PENDING.equalsIgnoreCase(status)) {
            return true;
        }
        return STATUS_GENERATED.equalsIgnoreCase(status)
            && row.Auto_Send_DocuSign_Email__c == true
            && String.isBlank(row.EnvelopID__c)
            && String.isBlank(row.Document_Error_Message__c);
    }

    /** 2.3 - underway AND the row moved within IN_FLIGHT_MINUTES (also reads LastModifiedDate). */
    public static Boolean inFlight(Documents__c row) {
        if (!generationUnderway(row)) {
            return false;
        }
        Datetime moved = row.LastModifiedDate;
        return moved == null || moved >= Datetime.now().addMinutes(-IN_FLIGHT_MINUTES);
    }

    /* ══ 2.0 - MODON's validator ══════════════════════════════════════════════ */

    /** Its prefix before the list of labels (AccountKYCValidationInvocable 1.4). */
    @TestVisible
    private static final String MODON_MISSING_PREFIX = 'The following KYC fields are missing:';

    /** Tests set this to MODON's message (null for a pass) instead of reading live metadata. */
    @TestVisible
    private static String modonMessageOverride;
    @TestVisible
    private static Boolean modonOverrideSet = false;

    public class ModonVerdict {
        public Boolean success = true;
        public String message;
        public List<String> missing = new List<String>();
    }

    /** One call to AccountKYCValidationInvocable, the answer kept word for word. */
    @TestVisible
    private static ModonVerdict modonValidation(Id documentId) {
        ModonVerdict v = new ModonVerdict();
        String message;
        Boolean ok;
        if (modonOverrideSet) {
            message = modonMessageOverride;
            ok = String.isBlank(message);
        } else {
            AccountKYCValidationInvocable.KYCRequest req = new AccountKYCValidationInvocable.KYCRequest();
            req.documentId = documentId;
            List<AccountKYCValidationInvocable.KYCResponse> res =
                AccountKYCValidationInvocable.validateKYC(new List<AccountKYCValidationInvocable.KYCRequest>{ req });
            ok = !res.isEmpty() && res[0].isSuccess == true;
            message = res.isEmpty() ? 'KYC validation returned no answer.' : res[0].errorMessage;
        }
        v.success = ok;
        v.message = ok ? null : message;
        v.missing = missingFrom(v.message);
        return v;
    }

    /** The labels in MODON's "The following KYC fields are missing: A, B" sentence; empty otherwise. */
    @TestVisible
    private static List<String> missingFrom(String message) {
        List<String> out = new List<String>();
        if (String.isBlank(message) || !message.startsWith(MODON_MISSING_PREFIX)) {
            return out;
        }
        for (String part : message.substringAfter(MODON_MISSING_PREFIX).split(',')) {
            if (String.isNotBlank(part)) { out.add(part.trim()); }
        }
        return out;
    }

    /* ══ 2.2 - fields MODON's Update KYC form hides (console only, see the header) ══ */

    /**
     * The person fields, as AccountKycController names them. 2.3: two, not three; MODON removed the
     * "Other Source of Income" requirement, so its validator never names it.
     */
    @TestVisible
    private static final String FIELD_OCCUPATION   = 'Occupation__pc';
    @TestVisible
    private static final String FIELD_EMPLOYER     = 'EmployerBusinessName__pc';

    /** AccountKycController EMPLOYED, compared lower cased against the trimmed value. */
    private static final String FORM_EMPLOYED     = 'employed';

    /** Tests pin the rows' labels (field API name to label) instead of reading MODON's live rows. */
    @TestVisible
    private static Map<String, String> hideableLabelsOverride;

    /**
     * MODON's own labels for the two rows, keyed by field, exactly as the validator prints them
     * (Field_Label__c, else the API name). Active Account rows only, which is where the validator
     * finds them for a person. Empty when MODON has neither active.
     */
    @TestVisible
    private static Map<String, String> hideableLabels() {
        if (hideableLabelsOverride != null) { return hideableLabelsOverride; }
        List<String> known = new List<String>{ FIELD_OCCUPATION, FIELD_EMPLOYER };
        Map<String, String> out = new Map<String, String>();
        for (Account_KYC_Validation__mdt r : Account_KYC_Validation__mdt.getAll().values()) {
            if (r.Is_Active__c != true
                || String.isBlank(r.Object_API_Name__c) || !r.Object_API_Name__c.trim().equalsIgnoreCase('Account')
                || String.isBlank(r.Field_API_Name__c)) {
                continue;
            }
            for (String field : known) {
                if (field.equalsIgnoreCase(r.Field_API_Name__c.trim())) {
                    out.put(field, String.isNotBlank(r.Field_Label__c) ? r.Field_Label__c : r.Field_API_Name__c);
                }
            }
        }
        return out;
    }

    /**
     * MODON's missing list without Occupation or Employer / Business Name when MODON's form hides them
     * from the buyer this row validates (it shows both only while Employment Status is Employed). The
     * buyer is found as the validator finds it: the row's Account__c, else the person account behind
     * PrimaryContact__c. Anything that is not a person account, or cannot be read, keeps MODON's list
     * unchanged.
     */
    @TestVisible
    private static List<String> withoutFieldsTheFormHides(Id documentId, List<String> missing) {
        Map<String, String> labels = hideableLabels();
        Set<String> candidates = new Set<String>();
        for (String field : labels.keySet()) {
            for (String m : missing) {
                if (m != null && m.trim().equalsIgnoreCase(labels.get(field).trim())) { candidates.add(field); }
            }
        }
        if (candidates.isEmpty() || documentId == null) { return missing; }

        List<Documents__c> rows = [
            SELECT Account__c, PrimaryContact__r.IsPersonAccount, PrimaryContact__r.AccountId
            FROM Documents__c WHERE Id = :documentId LIMIT 1
        ];
        if (rows.isEmpty()) { return missing; }
        Id accountId = rows[0].Account__c;
        if (accountId == null && rows[0].PrimaryContact__r != null
            && rows[0].PrimaryContact__r.IsPersonAccount == true) {
            accountId = rows[0].PrimaryContact__r.AccountId;
        }
        if (accountId == null) { return missing; }
        List<Account> buyers = [
            SELECT IsPersonAccount, Employment_Status__pc
            FROM Account WHERE Id = :accountId LIMIT 1
        ];
        if (buyers.isEmpty() || buyers[0].IsPersonAccount != true) { return missing; }

        /* both are shown only to the Employed */
        if (formValue(buyers[0].Employment_Status__pc) == FORM_EMPLOYED) { return missing; }
        Set<String> hiddenLabels = new Set<String>();
        for (String field : candidates) {
            hiddenLabels.add(labels.get(field).trim().toLowerCase());
        }

        List<String> kept = new List<String>();
        for (String m : missing) {
            if (m == null || !hiddenLabels.contains(m.trim().toLowerCase())) { kept.add(m); }
        }
        return kept;
    }

    /** The form's normalisation: trimmed, lower cased, blank for null. */
    private static String formValue(Object v) {
        return v == null ? '' : String.valueOf(v).trim().toLowerCase();
    }

    /** A FIELD requirement: named in the union list and in the fields of its own. */
    private static void add(GateDTO g, Set<String> seen, String label) {
        if (String.isBlank(label)) { return; }
        String key = label.trim().toLowerCase();
        if (seen.contains(key)) { return; }
        seen.add(key);
        g.missing.add(label.trim());
        g.missingFields.add(label.trim());
    }

    /** 1.1 - true once a Nintex package is named for the form (MODON's row, else the console switch). */
    @TestVisible
    private static Boolean templateConfigured() {
        if (templateConfiguredOverride != null) { return templateConfiguredOverride; }
        return AurelixKycFormGenerator.configured();
    }
}