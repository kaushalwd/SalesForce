/**********************************************************************************************************************
* Name               : ADHA_UndertakingDocumentTest
* Description        : Covers the bilingual undertaking. No test here calls out: the renderer is swapped for a stub,
*                      so a test run can never spend a render credit or reach any external service.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
* 2.0           Aurelix                     23 Aug 2026     One bilingual document instead of one per language.
**********************************************************************************************************************/
@isTest
private class ADHA_UndertakingDocumentTest {
    private static final String PM = 'Full Upfront Payment';
    private static final String SESSION_HASH = 'DOC-SESSION-HASH';

    /** Stands in for the renderer. Counts calls, so reuse can be proved rather than assumed. */
    private class StubRenderer implements ADHA_UndertakingDocument.Renderer {
        Integer calls = 0;
        String lastHtml;
        Boolean fail = false;
        public String toPdfBase64(String html) {
            calls++;
            lastHtml = html;
            return fail ? null : EncodingUtil.base64Encode(Blob.valueOf('%PDF-1.4 stub'));
        }
        /** Never consulted: these stubs fail by returning null on purpose, and the test
         *  asserts on the outcome rather than the reason. */
        public String lastFailure() {
            return null;
        }

    }

    @TestSetup
    static void setup() {
        insert new ADHA_Applicant__c(
            Application_Number__c = 'D0000001',
            Emirates_ID__c = '784-1990-3456789-3',
            Customer_Name__c = 'Document Applicant',
            Mobile_Number__c = '+971500000003',
            Service_Type__c = 'House Purchase Loan',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Exploring',
            Current_Attempt__c = 1,
            SLA_Start__c = System.now().addDays(-1),
            SLA_End__c = System.now().addDays(6),
            Session_Token_Hash__c = SESSION_HASH,
            Declaration_Session_Hash__c = SESSION_HASH
        );

        insert new ADHA_Unit__c(
            Plot_UID__c = 'DOC-0',
            Category_Type__c = 'A',
            Eligible_Service__c = 'House Purchase Loan',
            Villa_Type__c = 'Modern',
            Community__c = 'Wb4_03',
            Status__c = 'Available',
            Expose_To__c = 'Public',
            Masterplan_Number__c = 900,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15,
            Centroid_Y__c = 0.15,
            Rooms_Count__c = 5,
            Price__c = 1800000
        );
    }

    private static ADHA_Applicant__c applicant() {
        return [
            SELECT Id, Application_Number__c, Customer_Name__c, Masked_Emirates_ID__c, Service_Type__c,
                   Eligible_Categories__c, Approved_Loan_Amount__c, Preferred_Language__c, Journey_Stage__c,
                   SLA_Start__c, SLA_End__c, Current_Attempt__c,
                   Declaration_Session_Hash__c, Session_Token_Hash__c, Extra_Unit_Changes__c
            FROM ADHA_Applicant__c
            WHERE Application_Number__c = 'D0000001'
            LIMIT 1
        ];
    }

    /** Pins the settings the reservation path reads so org config cannot turn this suite red;
     *  custom metadata cannot be inserted in a test, this cache is the only way in. */
    private static void openTheGate() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Exploration_Mode__c = false,
            SLA_Days__c = 7,
            Max_Attempts__c = 2,
            Max_Unit_Changes__c = 2,
            Additional_Payment_Months__c = 3,
            Selectable_Statuses__c = 'Available'
        );
    }

    private static Id reserve(String language) {
        openTheGate();
        ADHA_ReservationService.confirm(applicant(), 'DOC-0', PM, language);
        return [
            SELECT Id FROM ADHA_Reservation__c
            WHERE Applicant__c = :applicant().Id AND Status__c = 'Submitted'
            LIMIT 1
        ].Id;
    }

    /* ---------- one document, both languages ---------- */

    @isTest
    static void oneDocumentCarriesBothLanguages() {
        Id reservationId = reserve('en');

        Test.startTest();
        String html = ADHA_UndertakingDocument.buildHtml(reservationId);
        Test.stopTest();

        System.assert(html.contains('Housing Reservation Undertaking'), 'the English title is present');
        System.assert(html.contains('تعهد حجز المسكن'), 'and the Arabic title beside it');
        System.assert(html.contains('I acknowledge'), 'the English undertaking body is present');
        System.assert(html.contains('أقرّ'), 'and the Arabic body in the same document');
        System.assert(html.contains('Emirates ID'), 'labels are bilingual too');
        System.assert(html.contains('رقم الهوية'), 'in both directions');
    }

    @isTest
    static void theLanguageTheCustomerReadDoesNotChangeTheDocument() {
        Id english = reserve('en');
        String fromEnglish = ADHA_UndertakingDocument.buildHtml(english);

        // Restamped rather than re-confirmed: confirm() returns early on a signed reservation for the
        // same unit, which is correct behaviour and the wrong way to reach the other language here.
        update new ADHA_Reservation__c(Id = english, Undertaking_Language__c = 'ar');

        Test.startTest();
        String fromArabic = ADHA_UndertakingDocument.buildHtml(english);
        Test.stopTest();

        String clausesEn = fromEnglish.substringBefore('<table class="acceptance">');
        String clausesAr = fromArabic.substringBefore('<table class="acceptance">');
        System.assertEquals(clausesEn, clausesAr,
            'the deed itself is identical; only the note of which language was read differs');
        System.assert(fromEnglish.contains('in English') && fromArabic.contains('in Arabic'),
            'and that note does follow the record');
    }

    @isTest
    static void theAcceptanceRecordsWhichLanguageWasRead() {
        Id reservationId = reserve('ar');

        Test.startTest();
        String html = ADHA_UndertakingDocument.buildHtml(reservationId);
        Test.stopTest();

        System.assert(html.contains('in Arabic'), 'the deed says which language was actually shown');
        System.assert(html.contains('باللغة العربية'), 'and says so in both halves');
    }

    /* ---------- pairing ---------- */

    @isTest
    static void matchingLanguagesArePairedClauseByClause() {
        // Grant is 10 lines in both languages. Built in memory: the fixture applicant is on a loan
        // product, and this asserts the renderer rather than the service-type mapping.
        ADHA_Reservation__c res = new ADHA_Reservation__c(
            Undertaking_Type__c = 'Grant',
            Undertaking_Version__c = null
        );

        Test.startTest();
        String html = ADHA_UndertakingDocument.clauses(ADHA_UndertakingDocument.textsFor(res));
        Test.stopTest();

        System.assert(html.contains('<table class="clauses">'), 'side by side, not stacked');
        System.assertEquals(10, html.countMatches('<td class="en"><p class="'),
            'one row per clause pair, and Grant is 10 lines in both languages');
    }

    @isTest
    static void mismatchedLanguagesAreStackedRatherThanMispaired() {
        // ADHA's Loan text is 19 English / 17 Arabic paragraphs, so pairing would put clauses
        // opposite the wrong translations. The asymmetry is ADHA's own (docs/arabic-approval-register.md).
        Id reservationId = reserve('en');

        Test.startTest();
        String html = ADHA_UndertakingDocument.buildHtml(reservationId);
        Test.stopTest();

        System.assert(html.contains('class="stacked"'), 'stacked whole rather than paired wrongly');
        System.assert(!html.contains('<table class="clauses">'), 'and definitely not side by side');
    }

    @isTest
    static void aMissingLanguageRefusesBecauseTheDocumentNeedsBoth() {
        ADHA_Reservation__c res = new ADHA_Reservation__c(Undertaking_Type__c = 'Nonexistent');

        Test.startTest();
        String message = null;
        try {
            ADHA_UndertakingDocument.textsFor(res);
        } catch (ADHA_UndertakingDocument.DocumentException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'half a bilingual deed is not a deed');
        System.assert(message.contains('both languages'), 'and the refusal says why');
    }

    /* ---------- drift ---------- */

    @isTest
    static void textChangedSinceAcceptanceRefusesToRender() {
        Id reservationId = reserve('en');
        update new ADHA_Reservation__c(Id = reservationId, Undertaking_Version__c = 'SOMETHING-OLD-v0');

        Test.startTest();
        String message = null;
        try {
            ADHA_UndertakingDocument.buildHtml(reservationId);
        } catch (ADHA_UndertakingDocument.DocumentException e) {
            message = e.getMessage();
        }
        Test.stopTest();

        System.assertNotEquals(null, message, 'signing words nobody agreed to is worse than failing');
        System.assert(message.contains('SOMETHING-OLD-v0'), 'the refusal names what was accepted');
    }

    /* ---------- bidi, dates and labels ---------- */

    @isTest
    static void latinValuesAreIsolatedSoTheArabicSideCannotReorderThem() {
        Id reservationId = reserve('en');

        Test.startTest();
        String html = ADHA_UndertakingDocument.buildHtml(reservationId);
        Test.stopTest();

        System.assert(html.contains('<bdi>784-1990-3456789-3</bdi>'),
            'without isolation the ID reads back to front next to Arabic');
    }

    @isTest
    static void datesAreNumericSoTheyReadTheSameInBothHalves() {
        Id reservationId = reserve('en');

        Test.startTest();
        String html = ADHA_UndertakingDocument.buildHtml(reservationId);
        Test.stopTest();

        System.assert(!html.contains('November'), 'a month name only works in one of the two languages');
        System.assert(!html.contains('August'), 'and the acceptance date is the other one');
    }

    @isTest
    static void thePaymentMethodAppearsInBothLanguages() {
        Id reservationId = reserve('en');

        Test.startTest();
        String html = ADHA_UndertakingDocument.buildHtml(reservationId);
        Test.stopTest();

        System.assert(html.contains('Full Upfront Payment'), 'the picklist value as stored');
        System.assert(html.contains('سداد كامل المبلغ دفعة واحدة'), 'and its Arabic reading');
    }

    @isTest
    static void anUnknownPaymentMethodShowsThroughRatherThanVanishing() {
        Test.startTest();
        String unknown = ADHA_UndertakingDocument.paymentMethodLabel('Something New', true);
        Test.stopTest();

        System.assertEquals('Something New', unknown, 'a new picklist value must not disappear');
    }

    /* ---------- the signature anchor ---------- */

    @isTest
    static void theSignatureAnchorIsPresentAndInvisible() {
        Id reservationId = reserve('en');

        Test.startTest();
        String html = ADHA_UndertakingDocument.buildHtml(reservationId);
        Test.stopTest();

        System.assert(html.contains('\\s1\\'), 'DocuSign needs the anchor to place the tab');
        System.assert(html.contains('.anchor { color: #ffffff'), 'the customer must not see the anchor');
        System.assertEquals(1, html.countMatches('\\s1\\'), 'one document, one signature');
    }

    /* ---------- structure ---------- */

    @isTest
    static void adhaSectionNumberingIsSetApartFromClauses() {
        Test.startTest();
        String first = ADHA_UndertakingDocument.paragraphStyle('Acknowledgements and Declarations:', 0);
        String section = ADHA_UndertakingDocument.paragraphStyle('First: Selection of a House', 3);
        String arabicSection = ADHA_UndertakingDocument.paragraphStyle('أولًا: اختيار مسكن', 3);
        String clause = ADHA_UndertakingDocument.paragraphStyle(
            'I acknowledge that I am entitled to two selection opportunities, and this line ends here.', 4);
        Test.stopTest();

        System.assertEquals('doc-heading', first, 'the first line is the title of the undertaking');
        System.assertEquals('lead', section, 'an early colon is ADHA section numbering');
        System.assertEquals('lead', arabicSection, 'the rule must not be English only');
        System.assertEquals('clause', clause, 'a long sentence is body text, not a heading');
    }

    @isTest
    static void blankBodiesProduceNoLines() {
        Test.startTest();
        List<String> out = ADHA_UndertakingDocument.lines('  \n \n ');
        Test.stopTest();
        System.assertEquals(0, out.size(), 'whitespace is not a clause');
    }

    /* ---------- masking ---------- */

    /** Deliberate 23 Aug 2026 change: the deed identifies its signatory in full, as a UAE
     *  undertaking is executed. The screen still masks it. */
    @isTest
    static void theDeedCarriesTheEmiratesIdInFull() {
        ADHA_Applicant__c app = new ADHA_Applicant__c(Emirates_ID__c = '784-1990-3456789-3');

        Test.startTest();
        String shown = ADHA_UndertakingDocument.emiratesId(app);
        Test.stopTest();

        System.assertEquals('784-1990-3456789-3', shown, 'a deed names who signed it');
    }

    @isTest
    static void theFullIdWinsOverAStoredMask() {
        ADHA_Applicant__c app = new ADHA_Applicant__c(
            Masked_Emirates_ID__c = '784-XXXX-XXXX111-1',
            Emirates_ID__c = '784-1990-3456789-3'
        );

        Test.startTest();
        String shown = ADHA_UndertakingDocument.emiratesId(app);
        Test.stopTest();

        System.assertEquals('784-1990-3456789-3', shown,
            'the mask is the fallback for a missing ID, not the preference');
    }

    @isTest
    static void aMissingIdFallsBackToWhateverMaskExists() {
        ADHA_Applicant__c app = new ADHA_Applicant__c(Masked_Emirates_ID__c = '784-XXXX-XXXX111-1');

        Test.startTest();
        String shown = ADHA_UndertakingDocument.emiratesId(app);
        Test.stopTest();

        System.assertEquals('784-XXXX-XXXX111-1', shown, 'something identifying beats a dash');
    }

    /* ---------- storing and reuse ---------- */

    /** The 25 Aug fallback: render() used to throw the moment Adobe returned null, and Adobe
     *  timeouts read to the customer as signing being broken. */
    @isTest
    static void pdfCoRendersWhenAdobeGivesUp() {
        Id reservationId = reserve('en');
        StubRenderer primary = new StubRenderer();
        primary.fail = true;
        StubRenderer fallback = new StubRenderer();
        ADHA_UndertakingDocument.renderer = primary;
        ADHA_UndertakingDocument.fallbackRenderer = fallback;

        Test.startTest();
        ADHA_UndertakingDocument.Rendered out = ADHA_UndertakingDocument.render(reservationId);
        Test.stopTest();

        System.assertNotEquals(null, out, 'a customer mid-signature still gets a deed');
        System.assert(String.isNotBlank(out.base64), 'and it carries bytes');
        System.assertEquals(1, primary.calls, 'the primary was tried first');
        System.assertEquals(1, fallback.calls, 'and the fallback only after it failed');
        System.assertEquals(true, out.viaFallback,
            'flagged on the result, because render() runs before the DocuSign callouts and must '
            + 'not write - the caller logs it once the callouts are done');
    }

    /** The fallback is second, not equal: pdf.co is metered and must not be spent needlessly. */
    @isTest
    static void pdfCoIsNotTouchedWhenAdobeSucceeds() {
        Id reservationId = reserve('en');
        StubRenderer primary = new StubRenderer();
        StubRenderer fallback = new StubRenderer();
        ADHA_UndertakingDocument.renderer = primary;
        ADHA_UndertakingDocument.fallbackRenderer = fallback;

        Test.startTest();
        ADHA_UndertakingDocument.Rendered out = ADHA_UndertakingDocument.render(reservationId);
        Test.stopTest();

        System.assertEquals(1, primary.calls);
        System.assertEquals(0, fallback.calls, 'no credit spent while Adobe is working');
        System.assertEquals(false, out.viaFallback);
    }

    /** Both gone is still a clean failure: the caller shows MSG_SIGNING_FAILED and nothing is written. */
    @isTest
    static void bothRenderersFailingStillThrows() {
        Id reservationId = reserve('en');
        StubRenderer primary = new StubRenderer();
        primary.fail = true;
        StubRenderer fallback = new StubRenderer();
        fallback.fail = true;
        ADHA_UndertakingDocument.renderer = primary;
        ADHA_UndertakingDocument.fallbackRenderer = fallback;

        Test.startTest();
        Boolean threw = false;
        try {
            ADHA_UndertakingDocument.render(reservationId);
        } catch (ADHA_UndertakingDocument.DocumentException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'no silent empty deed');
        System.assertEquals(1, fallback.calls, 'and the fallback was genuinely tried');
    }

    @isTest
    static void generateStoresTheDocumentOnceAndThenReusesIt() {
        Id reservationId = reserve('en');
        StubRenderer stub = new StubRenderer();
        ADHA_UndertakingDocument.renderer = stub;

        Test.startTest();
        ADHA_UndertakingDocument.Rendered first = ADHA_UndertakingDocument.generate(reservationId);
        ADHA_UndertakingDocument.Rendered second = ADHA_UndertakingDocument.generate(reservationId);
        Test.stopTest();

        System.assertEquals(false, first.reused, 'the first call renders');
        System.assertEquals(true, second.reused, 'the second must not spend another credit');
        System.assertEquals(1, stub.calls, 'exactly one render for two requests');
        System.assertNotEquals(null, first.contentVersionId, 'the document is filed against the reservation');
        System.assertEquals(first.base64, second.base64, 'the reused copy is the same bytes');
        System.assert(!first.fileName.contains('-en'), 'the file is bilingual, so it carries no language');
    }

    @isTest
    static void aRefusedRenderThrowsRatherThanFilingNothing() {
        Id reservationId = reserve('en');
        StubRenderer stub = new StubRenderer();
        stub.fail = true;
        ADHA_UndertakingDocument.renderer = stub;

        Test.startTest();
        Boolean threw = false;
        try {
            ADHA_UndertakingDocument.generate(reservationId);
        } catch (ADHA_UndertakingDocument.DocumentException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'a silent null would send an empty envelope');
        System.assertEquals(0, [
            SELECT COUNT() FROM Attachment WHERE ParentId = :reservationId
        ], 'nothing is filed when the render fails');
    }
}