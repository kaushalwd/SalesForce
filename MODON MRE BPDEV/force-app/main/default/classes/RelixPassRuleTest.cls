/**
 * RelixPassRuleTest - every branch of the pass rule, on in-memory rows (SCW-181).
 *
 * Version  Author       Date         Detail
 * 1.2      MODON Dev  26 Sep 2026  Review fixes: a company's entity AML screening (match, failed, pending, not
 *                                    screened) (F-04); the rule run as a standard user holding
 *                                    Relix_Integration (C-09).
 * 1.1      MODON Dev  25 Sep 2026  Relix plan R6 (docs/relix, 07 C-4, R-q, R-s). The clean fixtures carry their
 *                                    certificate; a pending identity check is now held, so the "failed check"
 *                                    list uses a finished-but-not-completed identity instead. New: the hold and
 *                                    its cut-off, the certificates, a failed AML, a risk level without a match,
 *                                    a refusal before the hold, the company register hold.
 */
@IsTest
private class RelixPassRuleTest {

    private static Relix_KYC_Case__c cleanIndividual(String persona) {
        return new Relix_KYC_Case__c(
            Persona__c = persona, Relix_Status__c = 'COMPLETED',
            Identity_Status__c = 'COMPLETED', Liveness_Passed__c = true, Face_Matched__c = true,
            Document_Read_Passed__c = true, Consent_Accepted__c = true,
            Aml_Status__c = 'completed', Aml_Is_Match__c = false,
            Sof_Status__c = 'complete', Sof_Verdict__c = 'sufficient',
            Kyc_Certificate_Ref__c = 'DOC-REF-KYC-001');
    }

    private static Relix_KYC_Case__c cleanCompany() {
        return new Relix_KYC_Case__c(Persona__c = 'CORPORATE_ENTITY', Relix_Status__c = 'COMPLETED',
            Kyb_Status__c = 'completed', Kyb_Verified__c = true, Case_Certificate_Ref__c = 'DOC-REF-CASE-001');
    }

    private static void pinHours() {
        RelixTestData.enable();
    }

    @IsTest
    static void openStatesStayOpenUntilTheLinkExpires() {
        Relix_KYC_Case__c c = new Relix_KYC_Case__c(Relix_Status__c = 'STARTED', Link_Expires_At__c = System.now().addDays(1));
        System.assertEquals('OPEN', RelixPassRule.decide(c).decision);
        c.Link_Expires_At__c = System.now().addMinutes(-1);
        System.assertEquals('EXPIRED', RelixPassRule.decide(c).decision);
        c.Relix_Status__c = 'IN_PROGRESS';
        System.assertEquals('OPEN', RelixPassRule.decide(c).decision);
        c.Relix_Status__c = null;
        System.assertEquals('OPEN', RelixPassRule.decide(c).decision);
    }

    @IsTest
    static void requiresAttentionNeedsReview() {
        Relix_KYC_Case__c c = new Relix_KYC_Case__c(Relix_Status__c = 'REQUIRES_ATTENTION');
        RelixPassRule.Verdict v = RelixPassRule.decide(c);
        System.assertEquals('NEEDS_REVIEW', v.decision);
        System.assert(v.reason.contains('flagged'));
    }

    @IsTest
    static void aCleanExpatPasses() {
        pinHours();
        RelixPassRule.Verdict v = RelixPassRule.decide(cleanIndividual('INDIVIDUAL_EXPAT'));
        System.assertEquals('PASSED', v.decision, '' + v.reason);
        Relix_KYC_Case__c noSof = cleanIndividual('INDIVIDUAL_UAE_GCC');
        noSof.Sof_Status__c = null;
        noSof.Sof_Verdict__c = null;
        System.assertEquals('PASSED', RelixPassRule.decide(noSof).decision, 'source of funds not asked for is fine');
    }

    @IsTest
    static void eachFailedCheckNeedsReviewWithItsOwnReason() {
        pinHours();
        Relix_KYC_Case__c c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Liveness_Passed__c = false;
        System.assert(RelixPassRule.decide(c).reason.contains('Liveness'));
        c = cleanIndividual('INDIVIDUAL_EXPAT'); c.Face_Matched__c = false;
        System.assert(RelixPassRule.decide(c).reason.contains('face'));
        c = cleanIndividual('INDIVIDUAL_EXPAT'); c.Document_Read_Passed__c = false;
        System.assert(RelixPassRule.decide(c).reason.contains('document'));
        c = cleanIndividual('INDIVIDUAL_EXPAT'); c.Consent_Accepted__c = false;
        System.assert(RelixPassRule.decide(c).reason.contains('consent'));
        c = cleanIndividual('INDIVIDUAL_EXPAT'); c.Aml_Status__c = 'pending';
        System.assert(RelixPassRule.decide(c).reason.contains('AML'));
        c = cleanIndividual('INDIVIDUAL_EXPAT'); c.Aml_Is_Match__c = true;
        System.assert(RelixPassRule.decide(c).reason.contains('match'));
        c = cleanIndividual('INDIVIDUAL_EXPAT'); c.Sof_Status__c = 'processing';
        System.assert(RelixPassRule.decide(c).reason.contains('source of funds'));
        c = cleanIndividual('INDIVIDUAL_EXPAT'); c.Sof_Verdict__c = 'insufficient';
        System.assert(RelixPassRule.decide(c).reason.contains('not sufficient'));
        // A PENDING identity is now a held check (C-4); a finished identity that did not complete still needs review.
        c = cleanIndividual('INDIVIDUAL_EXPAT'); c.Identity_Status__c = 'EXPIRED';
        System.assert(RelixPassRule.decide(c).reason.contains('identity'));
        for (Relix_KYC_Case__c each : new List<Relix_KYC_Case__c>{ c }) {
            System.assertEquals('NEEDS_REVIEW', RelixPassRule.decide(each).decision);
        }
    }

    @IsTest
    static void aDifferentPersonaFromRelixNeedsReview() {
        pinHours();
        Relix_KYC_Case__c c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Relix_Persona__c = 'INDIVIDUAL_NON_RESIDENT';
        RelixPassRule.Verdict v = RelixPassRule.decide(c);
        System.assertEquals('NEEDS_REVIEW', v.decision);
        System.assert(v.reason.contains('persona'), v.reason);
        c.Relix_Persona__c = 'individual_expat';
        System.assertEquals('PASSED', RelixPassRule.decide(c).decision, 'same persona, any case');
    }

    @IsTest
    static void aRefusedIdentityIsRefused() {
        Relix_KYC_Case__c c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Identity_Status__c = 'REFUSED';
        System.assertEquals('REFUSED', RelixPassRule.decide(c).decision);
    }

    @IsTest
    static void nonResidentsAlwaysNeedReview() {
        pinHours();
        RelixPassRule.Verdict v = RelixPassRule.decide(cleanIndividual('INDIVIDUAL_NON_RESIDENT'));
        System.assertEquals('NEEDS_REVIEW', v.decision);
        System.assert(v.reason.contains('enhanced due diligence'));
    }

    @IsTest
    static void aCompanyPassesOnTheRegisterCheck() {
        pinHours();
        Relix_KYC_Case__c c = cleanCompany();
        System.assertEquals('PASSED', RelixPassRule.decide(c).decision);
        c.Kyb_Verified__c = false;
        System.assert(RelixPassRule.decide(c).reason.contains('not verified'));
        c.Kyb_Status__c = null;
        System.assert(RelixPassRule.decide(c).reason.contains('not completed'));
        c.Kyb_Status__c = 'completed'; c.Kyb_Verified__c = true; c.Sof_Status__c = 'complete'; c.Sof_Verdict__c = 'insufficient';
        System.assertEquals('NEEDS_REVIEW', RelixPassRule.decide(c).decision);
    }

    // ================================================================ 1.1: pending checks, certificates, AML (C-4)

    @IsTest
    static void pendingChecksAreHeldOpenUntilTheCutOff() {
        pinHours();
        Relix_KYC_Case__c c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Aml_Status__c = 'pending';
        c.Analysis_Status__c = 'running';
        c.Ready_Since__c = System.now().addHours(-1);
        RelixPassRule.Verdict held = RelixPassRule.decide(c);
        Assert.areEqual(RelixPassRule.OPEN, held.decision, 'a pending check holds the case open');
        Assert.areEqual('Waiting for: AML screening, document analysis.', held.reason, 'the reason lists the pending checks');

        c.Ready_Since__c = null;
        Assert.areEqual(RelixPassRule.OPEN, RelixPassRule.decide(c).decision, 'no ready time yet is still a hold');

        c.Ready_Since__c = System.now().addHours(-25);
        RelixPassRule.Verdict late = RelixPassRule.decide(c);
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, late.decision, 'after RELIX_NOT_READY_HOURS the case needs review');
        Assert.areEqual('Checks incomplete after 24 hours: AML screening, document analysis.', late.reason,
            'the reason names the hours and the checks');
    }

    @IsTest
    static void theCutOffFollowsTheSetting() {
        RelixTestData.enable();
        RelixConfig.valueOverride.put('RELIX_NOT_READY_HOURS', '2');
        Relix_KYC_Case__c c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Sof_Status__c = 'pending';
        c.Ready_Since__c = System.now().addHours(-3);
        Assert.areEqual('Checks incomplete after 2 hours: source of funds.', RelixPassRule.decide(c).reason,
            'RELIX_NOT_READY_HOURS sets the cut-off');
    }

    @IsTest
    static void anIndividualNeedsTheKycCertificate() {
        pinHours();
        Relix_KYC_Case__c c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Kyc_Certificate_Ref__c = null;
        RelixPassRule.Verdict v = RelixPassRule.decide(c);
        Assert.areEqual(RelixPassRule.OPEN, v.decision, 'no certificate yet: held');
        Assert.areEqual('Waiting for: KYC certificate.', v.reason, 'the certificate is the pending item');
        c.Case_Certificate_Ref__c = 'DOC-REF-CASE-001';
        Assert.areEqual(RelixPassRule.OPEN, RelixPassRule.decide(c).decision, 'the case certificate does not replace it');
    }

    @IsTest
    static void aCompanyNeedsTheCaseCertificateAndItsRegisterCheck() {
        pinHours();
        Relix_KYC_Case__c c = cleanCompany();
        c.Case_Certificate_Ref__c = null;
        Assert.areEqual('Waiting for: case certificate.', RelixPassRule.decide(c).reason, 'a company waits for the case certificate');
        c = cleanCompany();
        c.Kyb_Status__c = 'pending';
        RelixPassRule.Verdict v = RelixPassRule.decide(c);
        Assert.areEqual(RelixPassRule.OPEN, v.decision, 'a register check still running is held');
        Assert.areEqual('Waiting for: company register check.', v.reason, 'the register check is named');
    }

    @IsTest
    static void amlFailedNeedsReviewAndRiskAloneDoesNotBlock() {
        pinHours();
        Relix_KYC_Case__c c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Aml_Status__c = 'failed';
        RelixPassRule.Verdict failed = RelixPassRule.decide(c);
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, failed.decision, 'a failed screening needs review');
        Assert.areEqual('AML screening failed.', failed.reason, 'the failure is named');

        c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Aml_Risk_Level__c = 'high';
        Assert.areEqual(RelixPassRule.PASSED, RelixPassRule.decide(c).decision, 'a risk level without a match does not block');

        c.Aml_Status__c = null;
        Assert.areEqual('AML screening has not completed.', RelixPassRule.decide(c).reason, 'no screening at all needs review');

        c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Sof_Status__c = 'failed';
        Assert.areEqual('The source of funds assessment has not completed.', RelixPassRule.decide(c).reason,
            'a failed source-of-funds assessment is not a pending one: it needs review');
    }

    @IsTest
    static void aCompanysEntityAmlScreeningCountsWhenRelixRanOne() {
        pinHours();
        Relix_KYC_Case__c matched = cleanCompany();
        matched.Aml_Status__c = 'completed';
        matched.Aml_Is_Match__c = true;
        matched.Aml_Risk_Level__c = 'high';
        RelixPassRule.Verdict match = RelixPassRule.decide(matched);
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, match.decision, 'an entity AML match needs review');
        Assert.areEqual('AML screening found a match.', match.reason, 'the match is named');

        Relix_KYC_Case__c failed = cleanCompany();
        failed.Aml_Status__c = 'failed';
        Assert.areEqual('AML screening failed.', RelixPassRule.decide(failed).reason, 'a failed screening needs review');

        Relix_KYC_Case__c pending = cleanCompany();
        pending.Aml_Status__c = 'pending';
        pending.Ready_Since__c = System.now().addHours(-1);
        RelixPassRule.Verdict held = RelixPassRule.decide(pending);
        Assert.areEqual(RelixPassRule.OPEN, held.decision, 'a pending entity screening is held');
        Assert.areEqual('Waiting for: AML screening.', held.reason, 'the screening is named');

        Relix_KYC_Case__c clean = cleanCompany();
        clean.Aml_Status__c = 'completed';
        clean.Aml_Is_Match__c = false;
        Assert.areEqual(RelixPassRule.PASSED, RelixPassRule.decide(clean).decision, 'a clean entity screening passes');
        Assert.areEqual(RelixPassRule.PASSED, RelixPassRule.decide(cleanCompany()).decision,
            'a company Relix did not screen (no amlScreening block) is decided as before');
    }

    @IsTest
    static void theRuleRunsForTheIntegrationUser() {
        pinHours();
        User integrationUser = RelixTestData.integrationUser();
        RelixPassRule.Verdict individual;
        RelixPassRule.Verdict company;

        Test.startTest();
        System.runAs(integrationUser) {
            individual = RelixPassRule.decide(cleanIndividual('INDIVIDUAL_EXPAT'));
            company = RelixPassRule.decide(cleanCompany());
        }
        Test.stopTest();

        Assert.areEqual(RelixPassRule.PASSED, individual.decision, 'the pure rule needs no record access: ' + individual.reason);
        Assert.areEqual(RelixPassRule.PASSED, company.decision, 'the same for a company: ' + company.reason);
    }

    @IsTest
    static void aRefusalWinsOverPendingChecksAndAttentionIsImmediate() {
        pinHours();
        Relix_KYC_Case__c c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Identity_Status__c = 'REJECTED';
        c.Aml_Status__c = 'pending';
        Assert.areEqual(RelixPassRule.REFUSED, RelixPassRule.decide(c).decision, 'a refusal is final before any hold');

        c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Relix_Status__c = 'REQUIRES_ATTENTION';
        c.Aml_Status__c = 'pending';
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, RelixPassRule.decide(c).decision,
            'REQUIRES_ATTENTION needs review at once, pending checks or not (R-q)');

        c = cleanIndividual('INDIVIDUAL_EXPAT');
        c.Relix_Persona__c = 'INDIVIDUAL_UAE_GCC';
        c.Identity_Status__c = 'REFUSED';
        Assert.areEqual(RelixPassRule.NEEDS_REVIEW, RelixPassRule.decide(c).decision, 'the persona check stays first');
    }
}