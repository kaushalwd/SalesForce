/**
 * RelixMockBodies - SANDBOX-ONLY TEST TOOL. Builds the JSON answers of the Relix (Dalil) mock served by RelixMockApi, in
 * the Dalil Client API v2 shapes (sections 2.2, 3.1-3.8), copied from the fixtures RelixMocks and
 * RelixTestData (which are @IsTest and cannot answer a live callout).
 *
 * NEVER DEPLOY TO PRODUCTION. Lives in sandbox-tools/relix-mock, outside force-app.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  26 Sep 2026  Relix end-to-end mock test in sfdev (docs/relix/11-mock-test-plan.md sections 1 and 4).
 *
 * DOCUMENTS (plan section 4, rows D01, D02). An individual case offers 8 references: KYC-CERT and CASE-CERT
 * (certificates, filed on the case row), UP-POA (proof_of_address, filed on 'Other Supporting Document'), UP-PASSPORT
 * (passport upload, not mapped: SKIPPED), PASSPORT-IMG (passport_image, filed on 'Passport'), FACE, SELFIE and SIGNATURE
 * (never downloaded). /buyer also lists KYC-CERT as uaekyc_certificate (de-duplicated by Salesforce). A company case
 * offers 4: CASE-CERT, UP-TL (trade_licence), UP-COI (certificate_of_incorporation) and UP-MOA (moa_aoa, not mapped).
 * The DOC_* scenarios act on PASSPORT-IMG (individual) or UP-TL (company). Every file is a real tiny PDF (614 bytes) or
 * PNG (69 bytes); documentContentHash is the lower-case SHA-256 hex of the bytes sent.
 *
 * Only fake data: names from the buyer-number formula, '[email]' and '[phone]' placeholders, relix-mock.invalid links.
 * The callback URL and its token are never echoed. No DML, no SOQL, no callouts, no logging.
 */
public with sharing class RelixMockBodies {

    // ---------------------------------------------------------------- document references
    public static final String REF_KYC_CERT = 'KYC-CERT';
    public static final String REF_CASE_CERT = 'CASE-CERT';
    public static final String REF_UP_POA = 'UP-POA';
    public static final String REF_UP_PASSPORT = 'UP-PASSPORT';
    public static final String REF_PASSPORT_IMG = 'PASSPORT-IMG';
    public static final String REF_FACE = 'FACE';
    public static final String REF_SELFIE = 'SELFIE';
    public static final String REF_SIGNATURE = 'SIGNATURE';
    public static final String REF_UP_TL = 'UP-TL';
    public static final String REF_UP_COI = 'UP-COI';
    public static final String REF_UP_MOA = 'UP-MOA';

    // ---------------------------------------------------------------- document fault sizes
    public static final Integer LISTED_TOO_LARGE = 5000000;
    public static final Integer LISTED_SMALL = 800;
    public static final Integer RECEIVED_TOO_LARGE = 1500;
    public static final String SHORT_HASH = 'deadbeef';

    // ---------------------------------------------------------------- messages (Dalil 2.2)
    public static final String MSG_CREATED = 'Request completed successfully';
    public static final String MSG_CASE = 'Case details fetched successfully';
    public static final String MSG_BUYER = 'Buyer details fetched successfully';
    public static final String MSG_DOCUMENT = 'Document fetched successfully';
    public static final String MSG_AML = 'AML details fetched successfully';
    public static final String MSG_SOF = 'Source-of-funds details fetched successfully';
    public static final String MSG_ANALYSIS = 'Case analysis details fetched successfully';
    public static final String MSG_KYB = 'KYB details fetched successfully';
    public static final String NO_CONTENT_MESSAGE = 'Object storage is not configured.';

    private static final String MIME_PDF = 'application/pdf';
    private static final String MIME_PNG = 'image/png';
    private static final String SOURCE_UPLOAD = 'upload';
    private static final String SOURCE_GENERATED = 'generated';
    private static final String PLACE_KYC_CERT = 'KYC_CERT';
    private static final String PLACE_CASE_CERT = 'CASE_CERT';
    private static final String PLACE_UPLOAD = 'UPLOAD';
    private static final String PLACE_BUYER = 'BUYER';
    private static final String TYPE_UAEKYC_CERTIFICATE = 'uaekyc_certificate';
    private static final String COMPLETED_LOWER = 'completed';
    private static final String PENDING_LOWER = 'pending';
    private static final String ISO_FORMAT = 'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'';
    private static final String DIGEST = 'SHA-256';
    private static final String PAD_BYTE_HEX = '20';
    private static final Long MILLIS = 1000;
    private static final Integer UID_BASE = 100000000;
    private static final Integer SPONSOR_BASE = 900000000;
    private static final String ERROR_REF_PREFIX = 'RX-MOCK-';

    // Arabic sample words as escapes (the source stays ASCII): "test name", "engineer", "sponsor".
    private static final String AR_NAME = 'اختبار';
    private static final String AR_OCCUPATION = 'مهندس';
    private static final String AR_SPONSOR = 'كفيل';

    /** A one-page PDF, 614 bytes, text "RELIX MOCK DOCUMENT - SANDBOX TEST ONLY", with a valid xref table. */
    private static final String PDF_BASE64 =
        'JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9L'
        + 'aWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAg'
        + 'MCA2MTIgNzkyXSAvQ29udGVudHMgNCAwIFIgL1Jlc291cmNlcyA8PCAvRm9udCA8PCAvRjEgNSAwIFIgPj4gPj4gPj4KZW5kb2JqCjQgMCBv'
        + 'YmoKPDwgL0xlbmd0aCA3MCA+PgpzdHJlYW0KQlQgL0YxIDEyIFRmIDcyIDcyMCBUZCAoUkVMSVggTU9DSyBET0NVTUVOVCAtIFNBTkRCT1gg'
        + 'VEVTVCBPTkxZKSBUaiBFVAplbmRzdHJlYW0KZW5kb2JqCjUgMCBvYmoKPDwgL1R5cGUgL0ZvbnQgL1N1YnR5cGUgL1R5cGUxIC9CYXNlRm9u'
        + 'dCAvSGVsdmV0aWNhID4+CmVuZG9iagp4cmVmCjAgNgowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAwMDA1'
        + 'OCAwMDAwMCBuIAowMDAwMDAwMTE1IDAwMDAwIG4gCjAwMDAwMDAyNDEgMDAwMDAgbiAKMDAwMDAwMDM2MSAwMDAwMCBuIAp0cmFpbGVyCjw8'
        + 'IC9TaXplIDYgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjQzMQolJUVPRgo=';

    /** A 1x1 RGB PNG, 69 bytes. */
    private static final String PNG_BASE64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR42mPQy14BAAIMAUIWfWVMAAAAAElFTkSuQmCC';

    /** One document a case offers. */
    public class Doc {
        public String ref;
        public String name;
        public String label;
        public String mime;
        public String source;
        public String place;
    }

    private static final List<Doc> INDIVIDUAL_DOCS = new List<Doc>{
        doc(REF_KYC_CERT, 'kyc_certificate', 'KYC Certificate', MIME_PDF, SOURCE_GENERATED, PLACE_KYC_CERT),
        doc(REF_CASE_CERT, 'case_certificate', 'Case Certificate', MIME_PDF, SOURCE_GENERATED, PLACE_CASE_CERT),
        doc(REF_UP_POA, 'proof_of_address', 'Proof of Address', MIME_PDF, SOURCE_UPLOAD, PLACE_UPLOAD),
        doc(REF_UP_PASSPORT, 'passport', 'Passport Copy', MIME_PNG, SOURCE_UPLOAD, PLACE_UPLOAD),
        doc(REF_PASSPORT_IMG, 'passport_image', 'Passport Image', MIME_PNG, SOURCE_GENERATED, PLACE_BUYER),
        doc(REF_FACE, 'person_face', 'Face Image', MIME_PNG, SOURCE_GENERATED, PLACE_BUYER),
        doc(REF_SELFIE, 'capture_selfie', 'Selfie', MIME_PNG, SOURCE_GENERATED, PLACE_BUYER),
        doc(REF_SIGNATURE, 'digital_signature', 'Digital Signature', MIME_PNG, SOURCE_GENERATED, PLACE_BUYER)
    };

    private static final List<Doc> COMPANY_DOCS = new List<Doc>{
        doc(REF_CASE_CERT, 'case_certificate', 'Case Certificate', MIME_PDF, SOURCE_GENERATED, PLACE_CASE_CERT),
        doc(REF_UP_TL, 'trade_licence', 'Trade Licence', MIME_PDF, SOURCE_UPLOAD, PLACE_UPLOAD),
        doc(REF_UP_COI, 'certificate_of_incorporation', 'Certificate of Incorporation', MIME_PDF, SOURCE_UPLOAD, PLACE_UPLOAD),
        doc(REF_UP_MOA, 'moa_aoa', 'Memorandum of Association', MIME_PDF, SOURCE_UPLOAD, PLACE_UPLOAD)
    };

    private static Doc doc(String ref, String name, String label, String mime, String source, String place) {
        Doc d = new Doc();
        d.ref = ref;
        d.name = name;
        d.label = label;
        d.mime = mime;
        d.source = source;
        d.place = place;
        return d;
    }

    // ================================================================ envelopes

    /**
     * An error envelope: {"error":{"status","code","message","errorRef"[,"details"|"detail"]}}.
     * @param status      the HTTP status
     * @param code        Dalil's stable error code
     * @param message     the human message
     * @param details     the field list, or null
     * @param detailAlias true to send the field list under "detail" (the alias the client also accepts)
     * @return the JSON text
     */
    public static String error(Integer status, String code, String message, List<Object> details, Boolean detailAlias) {
        Map<String, Object> err = new Map<String, Object>{
            'status' => status, 'code' => code, 'message' => message, 'errorRef' => ERROR_REF_PREFIX + status
        };
        if (details != null) {
            err.put(detailAlias == true ? 'detail' : 'details', details);
        }
        return JSON.serialize(new Map<String, Object>{ 'error' => err });
    }

    /**
     * A 2xx answer without a data object (the client's malformed_response).
     * @param nowEpoch the mock's now
     * @return the JSON text
     */
    public static String malformed(Long nowEpoch) {
        return JSON.serialize(new Map<String, Object>{ 'fetchedAt' => iso(nowEpoch), 'message' => 'ok' });
    }

    private static String envelope(String message, String caseId, Map<String, Object> data, Long nowEpoch) {
        Map<String, Object> m = new Map<String, Object>{ 'fetchedAt' => iso(nowEpoch), 'message' => message };
        if (caseId != null) {
            m.put('caseId', caseId);
        }
        m.put('data', data);
        return JSON.serialize(m);
    }

    // ================================================================ 3.1 create

    /**
     * POST /buyer-journeys answer (200). CREATE_NO_CASEID leaves the caseId out; EMAIL_FAILED reports a failed email.
     * @param c        the new case (encoded: c.id set)
     * @param request  the create body (already contract-checked)
     * @param nowEpoch the mock's now
     * @return the JSON text
     */
    public static String created(RelixMockCatalog.MockCase c, Map<String, Object> request, Long nowEpoch) {
        String code = c.scenario.code;
        Map<String, Object> buyer = (Map<String, Object>) request.get('buyerDetails');
        Map<String, Object> data = new Map<String, Object>{
            'caseStatus' => RelixMockCatalog.STARTED,
            'persona' => RelixMockCatalog.personaType(c.persona),
            'caseCreatedAt' => iso(c.epoch)
        };
        if (request.containsKey('callbackUrl')) {
            data.put('callback', new Map<String, Object>{ 'registered' => true });
        }
        data.put('caseDetails', new Map<String, Object>{
            'propertyRef' => request.get('propertyRef'), 'journeyConfigId' => 'MOCK-JC-' + c.persona,
            'templateVersion' => '1', 'authority' => 'MOCK'
        });
        data.put('buyerDetails', new Map<String, Object>{ 'buyerRef' => buyer.get('buyerRef') });
        data.put('notification', notification(code == 'EMAIL_FAILED', nowEpoch));
        data.put('journeyDetails', new Map<String, Object>{
            'journeyLink' => 'https://relix-mock.invalid/j/' + c.id,
            'journeyLinkExpiry' => iso(RelixMockCatalog.linkExpiry(c))
        });
        return envelope(MSG_CREATED, code == 'CREATE_NO_CASEID' ? null : c.id, data, nowEpoch);
    }

    private static Map<String, Object> notification(Boolean failed, Long nowEpoch) {
        Map<String, Object> n = new Map<String, Object>{ 'channel' => 'email', 'recipient' => '[email]' };
        if (failed) {
            n.put('status', 'failed');
            n.put('failureReason', 'mailbox unavailable');
        } else {
            n.put('status', 'sent');
            n.put('sentAt', iso(nowEpoch));
        }
        return n;
    }

    // ================================================================ 3.2 case

    /**
     * GET /cases/{id} answer (200), built from the timeline. The check blocks appear only once the case is final.
     * @param c        the case
     * @param nowEpoch the mock's now
     * @return the JSON text
     */
    public static String caseRead(RelixMockCatalog.MockCase c, Long nowEpoch) {
        String status = RelixMockCatalog.status(c, nowEpoch);
        Boolean done = RelixMockCatalog.isFinal(c, nowEpoch);
        Map<String, Object> data = new Map<String, Object>{
            'caseStatus' => status,
            'personaType' => RelixMockCatalog.personaType(c.persona),
            'propertyRef' => RelixMockCatalog.propertyRefOf(c),
            'createdAt' => iso(c.epoch)
        };
        if (status != RelixMockCatalog.STARTED) {
            data.put('startedAt', iso(c.epoch + c.u));
        }
        if (status != RelixMockCatalog.STARTED && status != RelixMockCatalog.IN_PROGRESS) {
            data.put('submittedAt', iso(c.epoch + 2L * c.u));
        }
        if (done) {
            data.put('completedAt', iso(c.epoch + 4L * c.u));
        }
        data.put('linkExpiresAt', iso(RelixMockCatalog.linkExpiry(c)));
        data.put('buyerBasicDetails', basicDetails(c));
        if (done) {
            addChecks(data, c, RelixMockCatalog.held(c, nowEpoch));
        }
        return envelope(MSG_CASE, c.id, data, nowEpoch);
    }

    private static Map<String, Object> basicDetails(RelixMockCatalog.MockCase c) {
        Boolean company = RelixMockCatalog.isCompany(c);
        return new Map<String, Object>{
            'buyerRef' => 'MOCK-' + RelixMockCatalog.seq6(c.buyer),
            'name' => company ? 'RLXT MOCK COMPANY ' + RelixMockCatalog.seq6(c.buyer) : RelixMockCatalog.fullName(c),
            'email' => '[email]',
            'phone' => '[phone]',
            'type' => company ? 'entity' : 'individual'
        };
    }

    private static void addChecks(Map<String, Object> data, RelixMockCatalog.MockCase c, Boolean held) {
        String code = c.scenario.code;
        if (!RelixMockCatalog.isCompany(c)) {
            data.put('buyerIdentityDetails', identity(c, held));
        }
        data.put('amlScreening', amlSummary(c, held));
        data.put('sourceOfFunds', sofSummary(c, held));
        data.put('caseCorrelationAnalysis', analysisSummary(c, held));
        data.put('consents', new List<Object>{ new Map<String, Object>{
            'stepCode' => 'start', 'consentId' => 'consent_pdpl', 'consentVersion' => '1',
            'accepted' => code != 'NO_CONSENT', 'acceptedAt' => iso(c.epoch + c.u)
        } });
        data.put('documents', uploads(c));
        data.put('certificates', certificates(c));
    }

    private static Map<String, Object> identity(RelixMockCatalog.MockCase c, Boolean held) {
        String code = c.scenario.code;
        String status = code == 'ID_REFUSED' ? 'REFUSED' : 'COMPLETED';
        if (code == 'IDENTITY_PENDING_THEN_DONE' && held) {
            status = 'PENDING';
        }
        Map<String, Object> outcome = new Map<String, Object>{
            'status' => status, 'levelCode' => 'UAEKYC-VL-001',
            'livenessPassed' => code != 'LIVENESS_FAIL', 'faceMatchRan' => true,
            'faceMatched' => code != 'FACE_MISMATCH', 'selfieAttempts' => 1,
            'documentReadPassed' => code != 'DOCREAD_FAIL', 'documentReadAttempts' => 1
        };
        return new Map<String, Object>{
            'fullName' => RelixMockCatalog.fullName(c),
            'dateOfBirth' => RelixMockCatalog.BIRTH_DATE,
            'nationality' => RelixMockCatalog.alpha3(c),
            'uidNumber' => 'UID-' + RelixMockCatalog.seq7(c.buyer),
            'activePassport' => new Map<String, Object>{
                'documentNo' => RelixMockCatalog.passportNumber(c.buyer), 'documentType' => 'ORDINARY PASSPORT',
                'documentIssueCountry' => RelixMockCatalog.alpha3(c), 'expiryDate' => RelixMockCatalog.PASSPORT_EXPIRY
            },
            'emiratesIdDetail' => new Map<String, Object>{
                'emiratesId' => RelixMockCatalog.eidDigits(c.buyer), 'expiryDate' => RelixMockCatalog.EID_EXPIRY
            },
            'verificationOutcome' => outcome
        };
    }

    private static Map<String, Object> amlSummary(RelixMockCatalog.MockCase c, Boolean held) {
        String code = c.scenario.code;
        Map<String, Object> m = new Map<String, Object>{
            'amlRefToken' => 'AML-MOCK-' + RelixMockCatalog.seq6(c.buyer),
            'subjectType' => RelixMockCatalog.isCompany(c) ? 'entity' : 'person'
        };
        if (held && (code == 'AML_PENDING_THEN_DONE' || code == 'CO_AML_PENDING_THEN_DONE')) {
            m.put('status', PENDING_LOWER);
            return m;
        }
        if (code == 'AML_FAILED') {
            m.put('status', 'failed');
            return m;
        }
        Boolean match = code == 'AML_MATCH' || code == 'CO_AML_MATCH';
        m.put('status', COMPLETED_LOWER);
        m.put('isMatch', match);
        m.put('riskLevel', riskOf(code, match));
        m.put('totalHits', match ? 2 : 0);
        return m;
    }

    private static String riskOf(String code, Boolean match) {
        if (match) {
            return 'high';
        }
        return code == 'AML_RISK_MEDIUM' ? 'medium' : 'low';
    }

    private static Map<String, Object> sofSummary(RelixMockCatalog.MockCase c, Boolean held) {
        String code = c.scenario.code;
        Map<String, Object> m = new Map<String, Object>{ 'sofVendorRefToken' => 'SOF-MOCK-' + RelixMockCatalog.seq6(c.buyer) };
        if (held && code == 'SOF_PENDING_THEN_DONE') {
            m.put('sofCaseStatus', 'processing');
            return m;
        }
        Boolean insufficient = code == 'SOF_INSUFFICIENT' || code == 'CO_SOF_INSUFFICIENT';
        m.put('sofCaseStatus', 'complete');
        m.put('sofVerdict', insufficient ? 'insufficient' : 'sufficient');
        m.put('isSufficient', !insufficient);
        return m;
    }

    private static Map<String, Object> analysisSummary(RelixMockCatalog.MockCase c, Boolean held) {
        String code = c.scenario.code;
        Integer compared = RelixMockCatalog.isCompany(c) ? 8 : 12;
        if (held && code == 'ANALYSIS_RUNNING_THEN_DONE') {
            return comparison('running', 0, 0, 0, 0);
        }
        if (code == 'ANALYSIS_FLAGGED') {
            return comparison(COMPLETED_LOWER, 12, 9, 2, 1);
        }
        return comparison(COMPLETED_LOWER, compared, compared, 0, 0);
    }

    private static Map<String, Object> comparison(String status, Integer compared, Integer matched, Integer flagged, Integer notComparable) {
        return new Map<String, Object>{
            'status' => status, 'fieldsCompared' => compared, 'matched' => matched,
            'flagged' => flagged, 'notComparable' => notComparable
        };
    }

    private static List<Object> uploads(RelixMockCatalog.MockCase c) {
        List<Object> out = new List<Object>();
        for (Doc d : documentsFor(c)) {
            if (d.place == PLACE_UPLOAD) {
                out.add(new Map<String, Object>{
                    'documentRefId' => d.ref, 'documentName' => d.name, 'documentUploadedName' => fileName(d),
                    'documentUploadedType' => d.mime, 'documentSize' => listedSize(c, d),
                    'documentUploadedAt' => iso(c.epoch + 2L * c.u), 'documentExtractionStatus' => COMPLETED_LOWER
                });
            }
        }
        return out;
    }

    private static Map<String, Object> certificates(RelixMockCatalog.MockCase c) {
        String code = c.scenario.code;
        Map<String, Object> m = new Map<String, Object>();
        if (RelixMockCatalog.isCompany(c)) {
            if (code == 'CO_NO_CASE_CERT') {
                m.put('message', 'Not every check on this case has answered yet.');
                return m;
            }
            m.put('message', 'KYC certificate not issued for this case.');
        } else if (code == 'CERT_MISSING') {
            m.put('message', 'Not every check on this case has answered yet.');
        } else {
            m.put('kycCertificate', certificate(c, findDoc(c, REF_KYC_CERT)));
        }
        m.put('caseCertificate', certificate(c, findDoc(c, REF_CASE_CERT)));
        return m;
    }

    private static Map<String, Object> certificate(RelixMockCatalog.MockCase c, Doc d) {
        Blob content = content(c, d);
        return new Map<String, Object>{
            'documentRefId' => d.ref, 'documentUploadedType' => d.mime,
            'documentSize' => content.size(), 'documentContentHash' => sha256(content)
        };
    }

    // ================================================================ 3.3 buyer

    /**
     * GET /cases/{id}/buyer answer (200): the federal-register record. Identity values come from the buyer-number
     * formula (RelixMockCatalog), so they equal what the seed scripts stored.
     * @param c        the case (individual)
     * @param nowEpoch the mock's now
     * @return the JSON text
     */
    public static String buyer(RelixMockCatalog.MockCase c, Long nowEpoch) {
        Boolean resident = c.persona != RelixMockCatalog.PERSONA_NON_RESIDENT;
        String country = RelixMockCatalog.countryName(c);
        String code3 = RelixMockCatalog.alpha3(c);
        Map<String, Object> personal = new Map<String, Object>{
            'titleEn' => 'MR', 'firstNameEn' => RelixMockCatalog.FIRST_NAME,
            'secondNameEn' => RelixMockCatalog.middleName(c.buyer), 'familyNameEn' => RelixMockCatalog.lastName(c),
            'fullNameEn' => RelixMockCatalog.fullName(c), 'fullNameAr' => AR_NAME, 'genderEn' => 'MALE',
            'dateOfBirth' => RelixMockCatalog.BIRTH_DATE, 'placeOfBirthEn' => 'DUBAI', 'currentNationality' => code3,
            'occupationEn' => 'ENGINEER', 'occupationAr' => AR_OCCUPATION,
            'personClass' => resident ? 'Resident' : 'Non-Resident',
            'personClassification' => resident ? 'RESIDENCE' : 'VISITOR',
            'immigrationStatus' => 'ACTIVE', 'insideUAE' => 'Yes', 'mobileNo' => '0500000000'
        };
        Map<String, Object> details = new Map<String, Object>{
            'uaeKycId' => String.valueOf(c.buyer),
            'uidNumber' => UID_BASE + c.buyer,
            'personalInfo' => personal,
            'emiratesIdDetail' => new Map<String, Object>{
                'emiratesId' => RelixMockCatalog.eidDigits(c.buyer), 'documentNo' => 'EID-' + RelixMockCatalog.seq7(c.buyer),
                'documentTypeEn' => 'Emirates ID', 'issueDate' => RelixMockCatalog.EID_ISSUE,
                'expiryDate' => RelixMockCatalog.EID_EXPIRY, 'issuePlaceEn' => 'Abu Dhabi'
            },
            'activePassport' => new Map<String, Object>{
                'documentNo' => RelixMockCatalog.passportNumber(c.buyer), 'documentType' => 'ORDINARY PASSPORT',
                'documentIssueCountry' => country, 'documentIssueCountryAbbr' => code3,
                'documentNationality' => country, 'documentNationalityAbbr' => code3,
                'issueDate' => RelixMockCatalog.PASSPORT_ISSUE, 'expiryDate' => RelixMockCatalog.PASSPORT_EXPIRY
            },
            'sponsorDetails' => new Map<String, Object>{
                'nameEn' => 'RLXT SPONSOR', 'nameAr' => AR_SPONSOR, 'sponsorNo' => SPONSOR_BASE + c.buyer
            },
            'personContactDetails' => new Map<String, Object>{
                'emirateEn' => 'ABU DHABI', 'cityEn' => 'ABU DHABI', 'areaEn' => 'MOCK AREA',
                'streetEn' => 'MOCK STREET', 'poBox' => '000000'
            },
            'validationResult' => new Map<String, Object>{
                'persona' => new Map<String, Object>{ 'type' => resident ? 'RESIDENCE' : 'VISITOR' },
                'dobMatch' => 'CORRECT', 'nationalityMatch' => 'CORRECT'
            }
        };
        Map<String, Object> data = new Map<String, Object>{
            'journeyToken' => 'MOCK-JOURNEY-' + RelixMockCatalog.seq6(c.buyer),
            'buyerDetails' => details,
            'warnings' => new List<Object>(),
            'errors' => new List<Object>(),
            'documents' => buyerDocuments(c)
        };
        return envelope(MSG_BUYER, c.id, data, nowEpoch);
    }

    private static List<Object> buyerDocuments(RelixMockCatalog.MockCase c) {
        Doc kyc = findDoc(c, REF_KYC_CERT);
        List<Object> out = new List<Object>{ buyerDocument(TYPE_UAEKYC_CERTIFICATE, kyc, listedSize(c, kyc)) };
        for (Doc d : documentsFor(c)) {
            if (d.place == PLACE_BUYER) {
                out.add(buyerDocument(d.name, d, listedSize(c, d)));
            }
        }
        return out;
    }

    private static Map<String, Object> buyerDocument(String type, Doc d, Integer size) {
        return new Map<String, Object>{ 'type' => type, 'documentRefId' => d.ref, 'mimeType' => d.mime, 'byteSize' => size };
    }

    // ================================================================ 3.5 AML, 3.8 SOF, 3.7 analysis, 3.6 KYB

    /**
     * GET /cases/{id}/aml answer (200).
     * @param c        the case
     * @param nowEpoch the mock's now
     * @return the JSON text
     */
    public static String aml(RelixMockCatalog.MockCase c, Long nowEpoch) {
        Map<String, Object> summary = amlSummary(c, RelixMockCatalog.held(c, nowEpoch));
        String status = (String) summary.get('status');
        Map<String, Object> data = new Map<String, Object>{
            'amlRefToken' => summary.get('amlRefToken'), 'subjectType' => summary.get('subjectType'),
            'status' => status, 'attempts' => status == PENDING_LOWER ? 0 : 1
        };
        if (status != COMPLETED_LOWER) {
            if (status == 'failed') {
                data.put('failureReason', 'The screening provider did not answer.');
            }
            return envelope(MSG_AML, c.id, data, nowEpoch);
        }
        Boolean match = (Boolean) summary.get('isMatch');
        data.put('verdict', new Map<String, Object>{
            'isMatch' => match, 'screeningStatus' => match ? 'Review' : 'Clear',
            'riskLevel' => summary.get('riskLevel'), 'riskScore' => match ? 80 : 20, 'truncated' => false
        });
        data.put('hitsSummary', new Map<String, Object>{
            'total' => match ? 2 : 0, 'sanctions' => match ? 1 : 0, 'pep' => match ? 1 : 0, 'adverseMedia' => 0
        });
        data.put('hits', match
            ? new List<Object>{ new Map<String, Object>{
                'id' => 'HIT-MOCK-1', 'caption' => 'Mock Sample Record', 'match' => true, 'matchScore' => 90,
                'riskScore' => 80, 'datasets' => new List<Object>{ 'Mock' } } }
            : new List<Object>());
        return envelope(MSG_AML, c.id, data, nowEpoch);
    }

    /**
     * GET /cases/{id}/sof answer (200).
     * @param c        the case
     * @param nowEpoch the mock's now
     * @return the JSON text
     */
    public static String sof(RelixMockCatalog.MockCase c, Long nowEpoch) {
        Map<String, Object> data = sofSummary(c, RelixMockCatalog.held(c, nowEpoch));
        String verdict = (String) data.get('sofVerdict');
        Boolean insufficient = verdict == 'insufficient';
        data.put('headline', verdict == null
            ? 'The source-of-funds assessment is still processing.'
            : 'Mock: the evidence is ' + verdict + '.');
        data.put('transactionCurrency', 'AED');
        data.put('flagsLength', insufficient ? 1 : 0);
        data.put('flags', insufficient
            ? new List<Object>{ new Map<String, Object>{
                'code' => 'MOCK_LOW_COVERAGE', 'severity' => 'medium', 'evidence' => 'Mock',
                'description' => 'Mock: the declared funds are not evidenced.' } }
            : new List<Object>());
        return envelope(MSG_SOF, c.id, data, nowEpoch);
    }

    /**
     * GET /cases/{id}/analysis answer (200).
     * @param c        the case
     * @param nowEpoch the mock's now
     * @return the JSON text
     */
    public static String analysis(RelixMockCatalog.MockCase c, Long nowEpoch) {
        Map<String, Object> summary = analysisSummary(c, RelixMockCatalog.held(c, nowEpoch));
        Integer flagged = (Integer) summary.get('flagged');
        Map<String, Object> data = new Map<String, Object>{
            'status' => summary.get('status'),
            'summary' => 'Mock: ' + summary.get('fieldsCompared') + ' field(s) compared.',
            'comparison' => new Map<String, Object>{
                'fieldsCompared' => summary.get('fieldsCompared'), 'matched' => summary.get('matched'),
                'flagged' => flagged, 'notComparable' => summary.get('notComparable')
            },
            'findingsLength' => flagged > 0 ? 1 : 0,
            'findings' => flagged > 0
                ? new List<Object>{ new Map<String, Object>{
                    'callNo' => 1, 'scope' => 'document_correlation', 'field' => 'Address', 'result' => 'flagged',
                    'detail' => 'Mock: a different address.' } }
                : new List<Object>()
        };
        return envelope(MSG_ANALYSIS, c.id, data, nowEpoch);
    }

    /**
     * GET /cases/{id}/kyb answer (200, companies). beneficialOwners is always present, even empty.
     * @param c        the case (company)
     * @param nowEpoch the mock's now
     * @return the JSON text
     */
    public static String kyb(RelixMockCatalog.MockCase c, Long nowEpoch) {
        String code = c.scenario.code;
        Boolean pending = code == 'CO_KYB_PENDING_THEN_DONE' && RelixMockCatalog.held(c, nowEpoch);
        Map<String, Object> data = new Map<String, Object>{
            'status' => pending ? PENDING_LOWER : COMPLETED_LOWER,
            'registryStatus' => pending ? PENDING_LOWER : 'resolved',
            'registryCaseId' => 'KYB-MOCK-' + RelixMockCatalog.seq6(c.buyer),
            'isVerified' => !pending && code != 'CO_KYB_UNVERIFIED',
            'beneficialOwners' => new List<Object>()
        };
        return envelope(MSG_KYB, c.id, data, nowEpoch);
    }

    // ================================================================ 3.4 document

    /**
     * GET /cases/{id}/documents/{ref} answer (200). DOC_BAD_HASH, DOC_SHORT_HASH, DOC_TOO_LARGE_RECEIVED and
     * DOC_NO_CONTENT shape the fault document; the other DOC_* faults are answered by RelixMockApi.
     * @param c        the case
     * @param ref      the document reference
     * @param nowEpoch the mock's now
     * @return the JSON text, or null when the case offers no such document
     */
    public static String document(RelixMockCatalog.MockCase c, String ref, Long nowEpoch) {
        Doc d = findDoc(c, ref);
        if (d == null) {
            return null;
        }
        String code = c.scenario.code;
        Boolean fault = isFaultDoc(c, d);
        Boolean noContent = fault && code == 'DOC_NO_CONTENT';
        Blob content = content(c, d);
        Map<String, Object> data = new Map<String, Object>{
            'documentRefId' => d.ref, 'documentName' => d.name, 'documentLabel' => d.label,
            'documentUploadedName' => fileName(d), 'documentUploadedType' => d.mime,
            'documentSize' => noContent ? 0 : content.size(), 'documentUploadedAt' => iso(c.epoch + 2L * c.u),
            'documentContentHash' => noContent ? '' : hashFor(code, fault, content),
            'documentSource' => d.source, 'documentExtractionStatus' => COMPLETED_LOWER,
            'documentDetectedType' => d.label, 'documentDetectedSide' => 'front', 'documentPageCount' => 1,
            'documentExtractedFields' => new Map<String, Object>(), 'documentExtractedAt' => iso(c.epoch + 3L * c.u),
            'documentContentBase64' => noContent ? null : EncodingUtil.base64Encode(content)
        };
        if (noContent) {
            data.put('documentContentMessage', NO_CONTENT_MESSAGE);
        }
        return envelope(MSG_DOCUMENT, c.id, data, nowEpoch);
    }

    private static String hashFor(String code, Boolean fault, Blob content) {
        if (fault && code == 'DOC_BAD_HASH') {
            return sha256(Blob.valueOf('other bytes'));
        }
        if (fault && code == 'DOC_SHORT_HASH') {
            return SHORT_HASH;
        }
        return sha256(content);
    }

    // ================================================================ documents: helpers

    /**
     * The documents a case offers.
     * @param c the case
     * @return 4 for a company, 8 for an individual
     */
    public static List<Doc> documentsFor(RelixMockCatalog.MockCase c) {
        return RelixMockCatalog.isCompany(c) ? COMPANY_DOCS : INDIVIDUAL_DOCS;
    }

    /**
     * One document of a case.
     * @param c   the case
     * @param ref the reference
     * @return the document, or null when the case offers no such reference
     */
    public static Doc findDoc(RelixMockCatalog.MockCase c, String ref) {
        for (Doc d : documentsFor(c)) {
            if (d.ref == ref) {
                return d;
            }
        }
        return null;
    }

    /**
     * The reference the DOC_* scenarios act on.
     * @param c the case
     * @return UP-TL for a company, PASSPORT-IMG for an individual
     */
    public static String faultRef(RelixMockCatalog.MockCase c) {
        return RelixMockCatalog.isCompany(c) ? REF_UP_TL : REF_PASSPORT_IMG;
    }

    private static Boolean isFaultDoc(RelixMockCatalog.MockCase c, Doc d) {
        return d.ref == faultRef(c) && c.scenario.code.startsWith('DOC_');
    }

    /**
     * The bytes of a document: the PDF or the PNG, padded to 1,500 bytes for DOC_TOO_LARGE_RECEIVED.
     * @param c the case
     * @param d the document
     * @return the bytes
     */
    public static Blob content(RelixMockCatalog.MockCase c, Doc d) {
        Blob base = EncodingUtil.base64Decode(d.mime == MIME_PDF ? PDF_BASE64 : PNG_BASE64);
        if (isFaultDoc(c, d) && c.scenario.code == 'DOC_TOO_LARGE_RECEIVED') {
            return pad(base, RECEIVED_TOO_LARGE);
        }
        return base;
    }

    private static Integer listedSize(RelixMockCatalog.MockCase c, Doc d) {
        if (isFaultDoc(c, d) && c.scenario.code == 'DOC_TOO_LARGE_LISTED') {
            return LISTED_TOO_LARGE;
        }
        if (isFaultDoc(c, d) && c.scenario.code == 'DOC_TOO_LARGE_RECEIVED') {
            return LISTED_SMALL;
        }
        return content(c, d).size();
    }

    private static Blob pad(Blob b, Integer size) {
        return EncodingUtil.convertFromHex(EncodingUtil.convertToHex(b) + PAD_BYTE_HEX.repeat(size - b.size()));
    }

    private static String fileName(Doc d) {
        return d.name + (d.mime == MIME_PDF ? '.pdf' : '.png');
    }

    /**
     * Lower-case SHA-256 hex.
     * @param b the bytes
     * @return 64 hex characters
     */
    public static String sha256(Blob b) {
        return EncodingUtil.convertToHex(Crypto.generateDigest(DIGEST, b));
    }

    /**
     * An epoch-seconds instant as Dalil writes it: yyyy-MM-ddTHH:mm:ss.SSSZ, GMT.
     * @param epochSeconds the instant
     * @return the text
     */
    public static String iso(Long epochSeconds) {
        return Datetime.newInstance(epochSeconds * MILLIS).formatGmt(ISO_FORMAT);
    }
}