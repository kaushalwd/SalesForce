/**
 * RelixPassRule - what Salesforce concludes from a Relix case, because Relix concludes nothing.
 *
 * Version  Author       Date         Detail
 * 1.3      MODON Dev  26 Sep 2026  Review fix (F-04). A company's entity AML screening now counts when Relix ran
 *                                    one: pending is held like the other checks; failed, a match, or not completed is
 *                                    NEEDS_REVIEW. A company without an amlScreening block is decided as before.
 * 1.2      MODON Dev  25 Sep 2026  Relix plan R6 (docs/relix, 07 C-4, R-q; 06 Q-05 option c). A COMPLETED case
 *                                    with a check still pending (the RelixResultService.isReady definition)
 *                                    stays OPEN with "Waiting for: ..." until Ready_Since__c is older than
 *                                    RELIX_NOT_READY_HOURS, then NEEDS_REVIEW "Checks incomplete after N hours: ...".
 *                                    An individual needs the KYC certificate, a company the case certificate.
 *                                    A failed AML screening is NEEDS_REVIEW; a risk level alone never blocks.
 *                                    A company's register check still pending is held the same way (02 section
 *                                    3.3). REQUIRES_ATTENTION stays NEEDS_REVIEW at once; the persona check stays
 *                                    first; a refused identity is REFUSED before any hold.
 * 1.1      MODON Dev  25 Sep 2026  SCW-182. A case Relix opened under a different persona from the
 *                                    one requested is NEEDS_REVIEW, whatever else it says: the wrong
 *                                    journey ran (Relix_Persona__c, recorded on send and on every read).
 * 1.0      MODON Dev  25 Sep 2026  SCW-181. Dalil: "the final compliance decision remains with
 *                                    MODON". No endpoint returns a pass or fail, so this rule turns
 *                                    the case status and the check results into one of OPEN, PASSED,
 *                                    NEEDS_REVIEW, REFUSED or EXPIRED. It is deliberately strict:
 *                                    anything not clearly passed is NEEDS_REVIEW with a reason a
 *                                    person can read. MODON compliance owns the final rule (review
 *                                    note R1, R4); this is the provisional one from the walkthrough.
 *
 * PHASE-1 RULE (Q-05 c), an individual passes when all of:
 *   caseStatus COMPLETED; identity COMPLETED with liveness, face match and document read passed;
 *   the KYC certificate issued; PDPL consent accepted; AML completed with no match (a risk level
 *   without a match is recorded but does not block); source of funds absent, or complete and
 *   sufficient. A non-resident (enhanced due diligence) never passes here: NEEDS_REVIEW.
 * A company passes when: caseStatus COMPLETED, the case certificate issued, the register check
 * completed and verified, the entity AML screening (when Relix ran one) completed with no match, and
 * source of funds absent or sufficient. Its POA is a separate individual case with its own decision.
 *
 * PENDING CHECKS. A COMPLETED case whose identity (individual), AML, register check
 * (company), source of funds or analysis is still running, or whose certificate is not issued yet,
 * is held OPEN. The hold ends RELIX_NOT_READY_HOURS after Ready_Since__c (the first read that saw
 * the case finished); then it is NEEDS_REVIEW. Final decisions (PASSED, REFUSED) are kept by the
 * caller, RelixKycService (R-n).
 *
 * OWNERSHIP. Owner: MODON. Pure: no SOQL, no DML (reads RelixConfig only).
 */
public with sharing class RelixPassRule {

    public static final String OPEN = 'OPEN';
    public static final String PASSED = 'PASSED';
    public static final String NEEDS_REVIEW = 'NEEDS_REVIEW';
    public static final String REFUSED = 'REFUSED';
    public static final String EXPIRED = 'EXPIRED';

    // Relix values, compared trimmed and upper-cased.
    private static final String STATUS_COMPLETED = 'COMPLETED';
    private static final String STATUS_ATTENTION = 'REQUIRES_ATTENTION';
    private static final String STATUS_STARTED = 'STARTED';
    private static final String CHECK_COMPLETED = 'COMPLETED';
    private static final String CHECK_PENDING = 'PENDING';
    private static final String CHECK_FAILED = 'FAILED';
    private static final String SOF_COMPLETE = 'COMPLETE';
    private static final String SOF_SUFFICIENT = 'SUFFICIENT';
    private static final String ANALYSIS_RUNNING = 'RUNNING';
    private static final Set<String> IDENTITY_PENDING = new Set<String>{ '', 'PENDING', 'IN_PROGRESS' };
    private static final Set<String> SOF_PENDING = new Set<String>{ 'PENDING', 'PROCESSING' };
    private static final List<String> REFUSED_MARKERS = new List<String>{ 'REFUS', 'FAIL', 'REJECT' };

    // Names of the pending checks, as RelixResultService words them.
    private static final String CHECK_IDENTITY = 'identity check';
    private static final String CHECK_AML = 'AML screening';
    private static final String CHECK_KYB = 'company register check';
    private static final String CHECK_SOF = 'source of funds';
    private static final String CHECK_ANALYSIS = 'document analysis';
    private static final String CHECK_KYC_CERTIFICATE = 'KYC certificate';
    private static final String CHECK_CASE_CERTIFICATE = 'case certificate';
    private static final String LIST_SEPARATOR = ', ';
    private static final String SENTENCE_END = '.';
    private static final String WAITING_FOR = 'Waiting for: ';
    private static final String INCOMPLETE_AFTER = 'Checks incomplete after {0} hours: {1}.';

    public class Verdict {
        public String decision;
        public String reason;
        public Verdict(String decision, String reason) { this.decision = decision; this.reason = reason; }
    }

    /** Decides from the row's check fields. Ignores Decision__c; the caller handles SUPERSEDED and final decisions. */
    public static Verdict decide(Relix_KYC_Case__c c) {
        Verdict persona = personaMismatch(c);
        if (persona != null) {
            return persona;
        }
        String st = upper(c.Relix_Status__c);
        if (st == STATUS_ATTENTION) {
            return new Verdict(NEEDS_REVIEW, 'Relix flagged this case for attention.');
        }
        if (st != STATUS_COMPLETED) {
            return notFinished(c, st);
        }
        Boolean company = RelixPersonaService.isCorporate(c.Persona__c);
        if (!company && identityRefused(c)) {
            return new Verdict(REFUSED, 'The identity check refused this person.');
        }
        List<String> pending = pendingChecks(c, company);
        if (!pending.isEmpty()) {
            return hold(c, pending);
        }
        return company ? decideCompany(c) : decideIndividual(c);
    }

    // ---------------------------------------------------------------- before the checks

    private static Verdict personaMismatch(Relix_KYC_Case__c c) {
        if (String.isNotBlank(c.Relix_Persona__c) && String.isNotBlank(c.Persona__c)
                && !c.Relix_Persona__c.trim().equalsIgnoreCase(c.Persona__c.trim())) {
            return new Verdict(NEEDS_REVIEW, 'Relix opened persona ' + c.Relix_Persona__c + ' but ' + c.Persona__c + ' was requested.');
        }
        return null;
    }

    private static Verdict notFinished(Relix_KYC_Case__c c, String st) {
        if (st == STATUS_STARTED && c.Link_Expires_At__c != null && c.Link_Expires_At__c < System.now()) {
            return new Verdict(EXPIRED, 'The link expired before the buyer started.');
        }
        return new Verdict(OPEN, null);
    }

    private static Boolean identityRefused(Relix_KYC_Case__c c) {
        String idStatus = upper(c.Identity_Status__c);
        for (String marker : REFUSED_MARKERS) {
            if (idStatus.contains(marker)) {
                return true;
            }
        }
        return false;
    }

    // ---------------------------------------------------------------- pending checks (C-4)

    /** The checks still running, the same definition as RelixResultService.isReady (plus the company register). */
    private static List<String> pendingChecks(Relix_KYC_Case__c c, Boolean company) {
        List<String> pending = new List<String>();
        if (company) {
            addIf(pending, upper(c.Kyb_Status__c) == CHECK_PENDING, CHECK_KYB);
        } else {
            addIf(pending, IDENTITY_PENDING.contains(upper(c.Identity_Status__c)), CHECK_IDENTITY);
        }
        addIf(pending, upper(c.Aml_Status__c) == CHECK_PENDING, CHECK_AML);
        addIf(pending, SOF_PENDING.contains(upper(c.Sof_Status__c)), CHECK_SOF);
        addIf(pending, upper(c.Analysis_Status__c) == ANALYSIS_RUNNING, CHECK_ANALYSIS);
        if (company) {
            addIf(pending, String.isBlank(c.Case_Certificate_Ref__c), CHECK_CASE_CERTIFICATE);
        } else {
            addIf(pending, String.isBlank(c.Kyc_Certificate_Ref__c), CHECK_KYC_CERTIFICATE);
        }
        return pending;
    }

    private static void addIf(List<String> pending, Boolean isPending, String check) {
        if (isPending) {
            pending.add(check);
        }
    }

    /** OPEN while the checks may still finish; NEEDS_REVIEW once Ready_Since__c is older than the cut-off. */
    private static Verdict hold(Relix_KYC_Case__c c, List<String> pending) {
        Integer hours = RelixConfig.notReadyHours();
        String checks = String.join(pending, LIST_SEPARATOR);
        if (c.Ready_Since__c != null && c.Ready_Since__c < System.now().addHours(-hours)) {
            return new Verdict(NEEDS_REVIEW, String.format(INCOMPLETE_AFTER, new List<Object>{ String.valueOf(hours), checks }));
        }
        return new Verdict(OPEN, WAITING_FOR + checks + SENTENCE_END);
    }

    // ---------------------------------------------------------------- final checks

    private static Verdict decideCompany(Relix_KYC_Case__c c) {
        if (!eq(c.Kyb_Status__c, CHECK_COMPLETED)) {
            return new Verdict(NEEDS_REVIEW, 'The company register check has not completed.');
        }
        if (c.Kyb_Verified__c != true) {
            return new Verdict(NEEDS_REVIEW, 'The company was not verified on the register.');
        }
        // F-04: a company not screened (blank status) is not blocked; a screening Relix ran must be clean.
        Verdict aml = String.isBlank(c.Aml_Status__c) ? null : aml(c);
        if (aml != null) {
            return aml;
        }
        Verdict sof = sourceOfFunds(c);
        if (sof != null) {
            return sof;
        }
        return new Verdict(PASSED, null);
    }

    private static Verdict decideIndividual(Relix_KYC_Case__c c) {
        Verdict identity = identity(c);
        if (identity != null) {
            return identity;
        }
        if (c.Consent_Accepted__c != true) {
            return new Verdict(NEEDS_REVIEW, 'Data processing consent was not recorded.');
        }
        Verdict aml = aml(c);
        if (aml != null) {
            return aml;
        }
        Verdict sof = sourceOfFunds(c);
        if (sof != null) {
            return sof;
        }
        if (c.Persona__c == RelixPersonaService.P_NON_RESIDENT) {
            return new Verdict(NEEDS_REVIEW, 'Non-resident buyers need enhanced due diligence review.');
        }
        return new Verdict(PASSED, null);
    }

    /** Null when the identity check passed in full; otherwise the NEEDS_REVIEW verdict. */
    private static Verdict identity(Relix_KYC_Case__c c) {
        if (upper(c.Identity_Status__c) != CHECK_COMPLETED) {
            return new Verdict(NEEDS_REVIEW, 'The identity check has not completed.');
        }
        if (c.Liveness_Passed__c != true) {
            return new Verdict(NEEDS_REVIEW, 'Liveness was not confirmed.');
        }
        if (c.Face_Matched__c != true) {
            return new Verdict(NEEDS_REVIEW, 'The face did not match the document.');
        }
        if (c.Document_Read_Passed__c != true) {
            return new Verdict(NEEDS_REVIEW, 'The identity document could not be read.');
        }
        return null;
    }

    /** Null when AML completed with no match; a risk level alone does not block (Q-05). */
    private static Verdict aml(Relix_KYC_Case__c c) {
        if (eq(c.Aml_Status__c, CHECK_FAILED)) {
            return new Verdict(NEEDS_REVIEW, 'AML screening failed.');
        }
        if (!eq(c.Aml_Status__c, CHECK_COMPLETED)) {
            return new Verdict(NEEDS_REVIEW, 'AML screening has not completed.');
        }
        if (c.Aml_Is_Match__c == true) {
            return new Verdict(NEEDS_REVIEW, 'AML screening found a match.');
        }
        return null;
    }

    /** Null when source of funds is fine or was not asked for; otherwise the NEEDS_REVIEW verdict. */
    private static Verdict sourceOfFunds(Relix_KYC_Case__c c) {
        if (String.isBlank(c.Sof_Status__c)) {
            return null;
        }
        if (!eq(c.Sof_Status__c, SOF_COMPLETE)) {
            return new Verdict(NEEDS_REVIEW, 'The source of funds assessment has not completed.');
        }
        if (!eq(c.Sof_Verdict__c, SOF_SUFFICIENT)) {
            return new Verdict(NEEDS_REVIEW, 'Source of funds evidence is not sufficient.');
        }
        return null;
    }

    private static Boolean eq(String a, String b) {
        return a != null && a.trim().equalsIgnoreCase(b);
    }

    private static String upper(String s) {
        return s == null ? '' : s.trim().toUpperCase();
    }
}