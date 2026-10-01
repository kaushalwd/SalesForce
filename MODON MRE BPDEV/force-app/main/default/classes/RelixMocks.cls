/**
 * RelixMocks - canned Relix (Dalil) answers for the detail reads, documents and the fuller case
 * shapes, used by the tests of the result, write-back and document classes.
 *
 * Version  Author       Date         Detail
 * 1.2      MODON Dev  26 Sep 2026  Review fix (K7). documentBadHash() now sends a valid 64-hex hash of other bytes,
 *                                    so it really gives HASH_MISMATCH; the old 8-hex shape is documentShortHash().
 * 1.1      MODON Dev  25 Sep 2026  Relix plan R6 (docs/relix, 07 R-s). Adds requestsTo() and caseReads(), so a
 *                                    request-count assert counts only the endpoints it means, and caseBody() for a
 *                                    case answer with any data block. Existing fixtures unchanged.
 * 1.0      MODON Dev  25 Sep 2026  Relix plan R3-R5 (docs/relix). Shaped on Dalil's Client API Reference
 *                                    v2 examples (3.2 case, 3.3 buyer, 3.4 document, 3.5 AML, 3.7 analysis,
 *                                    3.8 source of funds) with made-up values only. Complements
 *                                    RelixTestData (buyers, rows, config overrides, the Mock).
 *
 * ROUTING. RelixTestData.Mock answers with the FIRST registered fragment the endpoint contains, and
 * '/cases/' is contained in every read. mockFor() therefore registers the specific paths first
 * ('/buyer', '/documents/', '/aml', '/sof', '/analysis', '/kyb') and '/cases/' last.
 */
@IsTest
public class RelixMocks {

    public static final String CASE_ID = RelixTestData.CASE_ID;
    public static final String REF_KYC_CERT = 'DOC-REF-KYC-001';
    public static final String REF_CASE_CERT = 'DOC-REF-CASE-001';
    public static final String REF_PASSPORT = 'DOC-REF-PASSPORT-001';
    public static final String REF_FACE = 'DOC-REF-FACE-001';
    public static final String REF_SELFIE = 'DOC-REF-SELFIE-001';
    public static final String REF_SIGNATURE = 'DOC-REF-SIGNATURE-001';
    public static final String REF_UPLOAD_POA = 'DOC-REF-UP-POA-001';
    public static final String REF_UPLOAD_PASSPORT = 'DOC-REF-UP-PASSPORT-001';
    public static final String REF_TRADE_LICENCE = 'DOC-REF-UP-TL-001';
    public static final String REF_INCORPORATION = 'DOC-REF-UP-COI-001';
    public static final String REF_MOA = 'DOC-REF-UP-MOA-001';
    /** The sub-resources of a case, which caseReads() does not count. */
    private static final List<String> SUB_RESOURCES = new List<String>{
        '/buyer', '/documents/', '/aml', '/sof', '/analysis', '/kyb'
    };

    // ================================================================ GET /cases (API 3.2)

    /**
     * A finished individual case. pendingCheck: null for all checks final, or one of 'identity', 'aml',
     * 'sof', 'analysis', 'certificate' to leave that check unfinished.
     */
    public static String caseIndividual(String caseStatus, String persona, String pendingCheck, Boolean amlMatch) {
        String identityStatus = pendingCheck == 'identity' ? 'PENDING' : 'COMPLETED';
        String amlStatus = pendingCheck == 'aml' ? 'pending' : 'completed';
        String sofStatus = pendingCheck == 'sof' ? 'processing' : 'complete';
        String analysisStatus = pendingCheck == 'analysis' ? 'running' : 'completed';
        String certificates = pendingCheck == 'certificate'
            ? '"certificates":{"message":"Not every check on this case has answered yet.","caseCertificate":{"documentRefId":"' + REF_CASE_CERT + '","documentUploadedType":"application/pdf","documentSize":400000,"documentContentHash":"x"}}'
            : '"certificates":{"kycCertificate":{"documentRefId":"' + REF_KYC_CERT + '","documentUploadedType":"application/pdf","documentSize":600000,"documentContentHash":"x"},'
              + '"caseCertificate":{"documentRefId":"' + REF_CASE_CERT + '","documentUploadedType":"application/pdf","documentSize":400000,"documentContentHash":"y"}}';
        Boolean match = amlMatch == true;
        return '{"fetchedAt":"2026-09-25T11:30:00.000Z","message":"Case details fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"caseStatus":"' + caseStatus + '","personaType":"' + persona + '","propertyRef":"ACC-TEST",'
            + '"createdAt":"2026-09-25T10:00:00.000Z","startedAt":"2026-09-25T10:01:00.000Z","submittedAt":"2026-09-25T10:15:00.000Z",'
            + '"completedAt":"2026-09-25T10:20:00.000Z","linkExpiresAt":"2026-10-02T10:00:00.000Z",'
            + '"buyerBasicDetails":{"buyerRef":"BUYER-001","name":"Sample Buyer","email":"buyer@example.com","phone":"+971500000000","type":"individual"},'
            + '"buyerIdentityDetails":{"fullName":"SAMPLE BUYER","dateOfBirth":"1990-01-01","nationality":"IND","uidNumber":"UID-000000",'
            + '"activePassport":{"documentNo":"P0000000","documentType":"ORDINARY PASSPORT","documentIssueCountry":"IND","expiryDate":"2031-01-01"},'
            + '"emiratesIdDetail":{"emiratesId":"784199012345671","expiryDate":"2029-01-01"},'
            + '"verificationOutcome":{"status":"' + identityStatus + '","levelCode":"UAEKYC-VL-001","livenessPassed":true,"faceMatchRan":true,'
            + '"faceMatched":true,"selfieAttempts":1,"documentReadPassed":true,"documentReadAttempts":1}},'
            + '"amlScreening":{"amlRefToken":"AML-REF-001","subjectType":"person","status":"' + amlStatus + '","isMatch":' + match + ','
            + '"riskLevel":"' + (match ? 'high' : 'low') + '","totalHits":' + (match ? '2' : '0') + '},'
            + '"sourceOfFunds":{"sofVendorRefToken":"SOF-REF-001","sofCaseStatus":"' + sofStatus + '","sofVerdict":"sufficient","isSufficient":true},'
            + '"caseCorrelationAnalysis":{"status":"' + analysisStatus + '","fieldsCompared":12,"matched":12,"flagged":0,"notComparable":0},'
            + '"consents":[{"stepCode":"start","consentId":"consent_pdpl","consentVersion":"1","accepted":true,"acceptedAt":"2026-09-25T10:01:30.000Z"}],'
            + '"documents":[{"documentRefId":"' + REF_UPLOAD_POA + '","documentName":"proof_of_address","documentUploadedName":"address.pdf",'
            + '"documentUploadedType":"application/pdf","documentSize":90000,"documentUploadedAt":"2026-09-25T10:05:00.000Z","documentExtractionStatus":"completed"},'
            + '{"documentRefId":"' + REF_UPLOAD_PASSPORT + '","documentName":"passport","documentUploadedName":"passport.jpg",'
            + '"documentUploadedType":"image/jpeg","documentSize":150000,"documentUploadedAt":"2026-09-25T10:06:00.000Z","documentExtractionStatus":"completed"}],'
            + certificates + '}}';
    }

    /** A finished company case (CORPORATE_ENTITY): no identity block, company uploads, case certificate only. */
    public static String caseCorporate(String caseStatus, Boolean withCaseCertificate) {
        String certificates = withCaseCertificate == true
            ? '"certificates":{"message":"KYC certificate not issued for this case.","caseCertificate":{"documentRefId":"' + REF_CASE_CERT + '","documentUploadedType":"application/pdf","documentSize":400000,"documentContentHash":"y"}}'
            : '"certificates":{"message":"Not every check on this case has answered yet."}';
        return '{"fetchedAt":"2026-09-25T11:30:00.000Z","message":"Case details fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"caseStatus":"' + caseStatus + '","personaType":"CORPORATE_ENTITY","propertyRef":"ACC-TEST",'
            + '"completedAt":"2026-09-25T11:20:00.000Z","linkExpiresAt":"2026-10-02T10:00:00.000Z",'
            + '"buyerBasicDetails":{"buyerRef":"COMPANY-001","name":"Relix Test Co","type":"entity"},'
            + '"sourceOfFunds":{"sofCaseStatus":"complete","sofVerdict":"sufficient","isSufficient":true},'
            + '"caseCorrelationAnalysis":{"status":"completed","fieldsCompared":8,"matched":8,"flagged":0,"notComparable":0},'
            + '"consents":[{"stepCode":"start","consentId":"consent_pdpl","consentVersion":"1","accepted":true}],'
            + '"documents":['
            + upload(REF_TRADE_LICENCE, 'trade_licence', 'licence.pdf', 'application/pdf', 120000) + ','
            + upload(REF_INCORPORATION, 'certificate_of_incorporation', 'coi.pdf', 'application/pdf', 110000) + ','
            + upload(REF_MOA, 'moa_aoa', 'moa.pdf', 'application/pdf', 300000) + '],'
            + certificates + '}}';
    }

    private static String upload(String ref, String name, String fileName, String mime, Integer size) {
        return '{"documentRefId":"' + ref + '","documentName":"' + name + '","documentUploadedName":"' + fileName + '",'
            + '"documentUploadedType":"' + mime + '","documentSize":' + size + ',"documentUploadedAt":"2026-09-25T11:00:00.000Z",'
            + '"documentExtractionStatus":"completed"}';
    }

    // ================================================================ GET /cases/{id}/buyer (API 3.3)

    /** The federal-register record of an expat resident. nationalityName is activePassport.documentNationality. */
    public static String buyer(String nationalityName) {
        return '{"fetchedAt":"2026-09-25T11:30:00.000Z","message":"Buyer details fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"journeyToken":"JOURNEY-TOKEN-001","buyerDetails":{"uaeKycId":"100","uidNumber":123456789,'
            + '"personalInfo":{"titleEn":"MR","firstNameEn":"SAMPLE","secondNameEn":"MIDDLE","familyNameEn":"PERSON",'
            + '"fullNameEn":"SAMPLE MIDDLE PERSON","fullNameAr":"AR NAME","genderEn":"MALE","dateOfBirth":"1990-01-01",'
            + '"placeOfBirthEn":"MUMBAI","currentNationality":"IND","occupationEn":"ENGINEER","occupationAr":"AR OCCUPATION",'
            + '"personClass":"Resident","personClassification":"RESIDENCE","immigrationStatus":"ACTIVE","insideUAE":"Yes","mobileNo":"0500000000"},'
            + '"emiratesIdDetail":{"emiratesId":"784199012345671","documentNo":"DOC-000000","documentTypeEn":"Emirates ID",'
            + '"issueDate":"2024-01-01","expiryDate":"2029-01-01","issuePlaceEn":"Abu Dhabi"},'
            + '"activePassport":{"documentNo":"P0000000","documentType":"ORDINARY PASSPORT","documentIssueCountry":"' + nationalityName + '",'
            + '"documentIssueCountryAbbr":"IND","documentNationality":"' + nationalityName + '","documentNationalityAbbr":"IND",'
            + '"issueDate":"2021-01-01","expiryDate":"2031-01-01"},'
            + '"sponsorDetails":{"nameEn":"SPONSOR NAME","nameAr":"AR SPONSOR","sponsorNo":123456789},'
            + '"personContactDetails":{"emirateEn":"ABU DHABI","cityEn":"ABU DHABI","areaEn":"AREA NAME","streetEn":"STREET NAME","poBox":"000000"},'
            + '"validationResult":{"persona":{"type":"RESIDENCE"},"dobMatch":"CORRECT","nationalityMatch":"CORRECT"}},'
            + '"warnings":[],"errors":[],'
            + '"documents":[{"type":"uaekyc_certificate","documentRefId":"' + REF_KYC_CERT + '","mimeType":"application/pdf","byteSize":600000},'
            + '{"type":"passport_image","documentRefId":"' + REF_PASSPORT + '","mimeType":"image/jpeg","byteSize":150000},'
            + '{"type":"person_face","documentRefId":"' + REF_FACE + '","mimeType":"image/jpeg","byteSize":65000},'
            + '{"type":"capture_selfie","documentRefId":"' + REF_SELFIE + '","mimeType":"image/jpeg","byteSize":12000},'
            + '{"type":"digital_signature","documentRefId":"' + REF_SIGNATURE + '","mimeType":"image/tiff","byteSize":250000}]}}';
    }

    /** API 3.3 errors: "The identity check has not returned yet." */
    public static String buyerNotReady() {
        return RelixTestData.error(404, 'not_found', 'RX-ERROR-12', 'Record not found.');
    }

    // ================================================================ GET /cases/{id}/documents/{ref} (API 3.4)

    /** A document with its bytes inline and a SHA-256 hex hash of those bytes. */
    public static String document(String ref, String label, String mime, Blob content) {
        String hash = content == null ? '' : EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', content));
        String base64 = content == null ? 'null' : '"' + EncodingUtil.base64Encode(content) + '"';
        return '{"fetchedAt":"2026-09-25T11:40:00.000Z","message":"Document fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"documentRefId":"' + ref + '","documentName":"' + ref.toLowerCase() + '","documentLabel":"' + label + '",'
            + '"documentUploadedName":"file.bin","documentUploadedType":"' + mime + '",'
            + '"documentSize":' + (content == null ? 0 : content.size()) + ',"documentUploadedAt":"2026-09-25T10:05:00.000Z",'
            + '"documentContentHash":"' + hash + '","documentSource":"upload","documentExtractionStatus":"completed",'
            + '"documentDetectedType":"' + label + '","documentDetectedSide":"front","documentPageCount":1,'
            + '"documentExtractedFields":{"date":"2026-06-03"},"documentExtractedAt":"2026-09-25T10:06:00.000Z",'
            + '"documentContentBase64":' + base64
            + (content == null ? ',"documentContentMessage":"Object storage is not configured."' : '') + '}}';
    }

    /** Same shape, but a valid 64-hex SHA-256 of other bytes: the hash check applies and fails (HASH_MISMATCH). */
    public static String documentBadHash(String ref, Blob content) {
        String otherHash = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf('other bytes')));
        return document(ref, 'Passport', 'image/jpeg', content)
            .replace(EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', content)), otherHash);
    }

    /** Same shape, but an 8-hex hash ('deadbeef'): not a SHA-256, so it cannot be checked. */
    public static String documentShortHash(String ref, Blob content) {
        return document(ref, 'Passport', 'image/jpeg', content)
            .replace(EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', content)), 'deadbeef');
    }

    // ================================================================ GET /aml, /sof, /analysis (API 3.5, 3.8, 3.7)

    public static String amlMatch() {
        return '{"fetchedAt":"2026-09-25T11:40:00.000Z","message":"AML details fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"amlRefToken":"AML-REF-001","subjectType":"person","status":"completed","attempts":1,'
            + '"verdict":{"isMatch":true,"screeningStatus":"Review","riskLevel":"high","riskScore":80,"truncated":false},'
            + '"hitsSummary":{"total":2,"sanctions":1,"pep":1,"adverseMedia":0},'
            + '"hits":[{"id":"HIT-1","caption":"Sample Record","match":true,"matchScore":90,"riskScore":80,"datasets":["Sample"]}]}}';
    }

    public static String sof(String verdict) {
        return '{"fetchedAt":"2026-09-25T11:40:00.000Z","message":"Source-of-funds details fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"sofVendorRefToken":"SOF-REF-001","sofCaseStatus":"complete","sofVerdict":"' + verdict + '",'
            + '"isSufficient":' + (verdict == 'sufficient') + ',"headline":"The evidence is ' + verdict + ' -- see the findings.",'
            + '"transactionCurrency":"AED","flagsLength":0,"flags":[]}}';
    }

    public static String analysisFlagged() {
        return '{"fetchedAt":"2026-09-25T11:40:00.000Z","message":"Case analysis details fetched successfully","caseId":"' + CASE_ID + '",'
            + '"data":{"status":"completed","summary":"3 document(s) were analysed.","comparison":{"fieldsCompared":12,"matched":9,"flagged":2,"notComparable":1},'
            + '"findingsLength":1,"findings":[{"callNo":1,"scope":"document_correlation","field":"Address","result":"flagged","detail":"Different address."}]}}';
    }

    // ================================================================ one mock for a whole read

    /**
     * A mock answering every Relix read of one case. Pass null for an endpoint that should fall through to
     * the Mock's 404. Specific paths are registered before '/cases/' (see ROUTING above).
     */
    public static RelixTestData.Mock mockFor(String caseBody, String buyerBody, String documentBody,
                                                    String amlBody, String sofBody, String analysisBody, String kybBody) {
        RelixTestData.Mock m = new RelixTestData.Mock();
        if (buyerBody != null) { m.route('/buyer', RelixTestData.response(buyerBody.contains('"error"') ? 404 : 200, buyerBody)); }
        if (documentBody != null) { m.route('/documents/', RelixTestData.response(200, documentBody)); }
        if (amlBody != null) { m.route('/aml', RelixTestData.response(200, amlBody)); }
        if (sofBody != null) { m.route('/sof', RelixTestData.response(200, sofBody)); }
        if (analysisBody != null) { m.route('/analysis', RelixTestData.response(200, analysisBody)); }
        if (kybBody != null) { m.route('/kyb', RelixTestData.response(200, kybBody)); }
        if (caseBody != null) { m.route('/cases/', RelixTestData.response(200, caseBody)); }
        return m;
    }

    /** The untyped `data` object of a canned answer, for tests of pure methods. */
    public static Map<String, Object> dataOf(String body) {
        Map<String, Object> envelope = (Map<String, Object>) JSON.deserializeUntyped(body);
        return (Map<String, Object>) envelope.get('data');
    }

    // ================================================================ request counts (R-s)

    /** A GET /cases answer whose data object is the given JSON object text (for odd shapes). */
    public static String caseBody(String dataJson) {
        return '{"fetchedAt":"2026-09-25T11:30:00.000Z","message":"ok","caseId":"' + CASE_ID + '","data":' + dataJson + '}';
    }

    /** How many recorded Relix requests went to an endpoint containing the fragment. */
    public static Integer requestsTo(RelixTestData.Mock m, String fragment) {
        Integer n = 0;
        for (HttpRequest r : m.requests) {
            if (r.getEndpoint().contains(fragment)) {
                n++;
            }
        }
        return n;
    }

    /** How many recorded Relix requests were GET /cases/{id} itself, not one of its sub-resources. */
    public static Integer caseReads(RelixTestData.Mock m) {
        Integer n = 0;
        for (HttpRequest r : m.requests) {
            String endpoint = r.getEndpoint();
            Boolean sub = false;
            for (String s : SUB_RESOURCES) {
                sub = sub || endpoint.contains(s);
            }
            if (endpoint.contains('/cases/') && !sub) {
                n++;
            }
        }
        return n;
    }
}