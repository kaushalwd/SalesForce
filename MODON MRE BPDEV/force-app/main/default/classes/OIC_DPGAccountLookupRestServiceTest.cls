/**********************************************************************************************************************
 * Name               : OIC_DPGAccountLookupRestServiceTest
 * Description        : Test class for OIC_DPGAccountLookupRestService
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    21 09 2026      Initial coverage
 * 1.1           Priyanka                    22 09 2026      Comments for coverage changes (test class only).
 *                                                           Where: lookupPayload() and applyRestWithQueryIdentity()
 *                                                           send RequestContext.CustomerType / query CustomerType
 *                                                           so Section 0 identity passes. Without that, search
 *                                                           returns CTX-001 and coverage stays ~8%.
 **********************************************************************************************************************/
@isTest
public class OIC_DPGAccountLookupRestServiceTest {

    private static final String PERSON_EMAIL   = 'personlookup@example.com';
    private static final String PERSON_MOBILE  = '+971509998877';
    private static final String PERSON_EID     = '784-1990-5555555-1';
    private static final String ORG_EMAIL      = 'orgcontact@example.com';
    private static final String ORG_MOBILE     = '+971501234567';
    private static final String ORG_PHONE      = '+971502222333';
    private static final String ORG_TL         = 'TL-998877';
    private static final String ORG_UNIFIED    = 'UN-LOOKUP-1';
    private static final String ORG_TL_NO_CON  = 'TL-NOCONTACT';
    private static final String ORG_TL_PHONE   = 'TL-PHONEONLY';

    @testSetup
    static void setupTestData() {
        Account orgAcc = new Account(
            Name = 'Test Org Account',
            TradeLicenseNumber__c = ORG_TL,
            UnifiedNumber__c = ORG_UNIFIED
        );
        insert orgAcc;

        Contact con = new Contact(
            FirstName = 'Org',
            LastName = 'Contact',
            AccountId = orgAcc.Id,
            Email = ORG_EMAIL,
            MobilePhone = ORG_MOBILE
        );
        insert con;

        Account orgNoContact = new Account(
            Name = 'Org Without Contact',
            TradeLicenseNumber__c = ORG_TL_NO_CON
        );
        insert orgNoContact;

        Account orgPhoneAcc = new Account(
            Name = 'Org Phone Contact Account',
            TradeLicenseNumber__c = ORG_TL_PHONE
        );
        insert orgPhoneAcc;

        Contact phoneOnly = new Contact(
            FirstName = 'Phone',
            LastName = 'Only',
            AccountId = orgPhoneAcc.Id,
            Phone = ORG_PHONE
        );
        insert phoneOnly;

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account personAcc = new Account(
            RecordTypeId = personRtId,
            FirstName = 'Person',
            LastName = 'Lookup',
            PersonEmail = PERSON_EMAIL,
            PersonMobilePhone = PERSON_MOBILE,
            EIDNumber__pc = PERSON_EID
        );
        insert personAcc;
    }

    private static RestResponse applyRest(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/accountsearch/';
        req.httpMethod = 'POST';
        req.requestBody = jsonBody == null ? null : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        return res;
    }

    // v1.1 Priyanka 22 09 2026: query-string CustomerType so empty/malformed bodies still pass identity
    private static RestResponse applyRestWithQueryIdentity(String jsonBody) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/dpg/accountsearch/';
        req.httpMethod = 'POST';
        req.params.put('CustomerType', 'Customer');
        req.requestBody = jsonBody == null ? null : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        return res;
    }

    // v1.1 Priyanka 22 09 2026: every lookup JSON includes RequestContext.CustomerType (identity)
    private static String lookupPayload(Map<String, Object> lookupFields) {
        Map<String, Object> payload = lookupFields == null
            ? new Map<String, Object>()
            : new Map<String, Object>(lookupFields);
        payload.put('RequestContext', new Map<String, Object>{
            'CustomerType' => 'Customer'
        });
        return JSON.serialize(payload);
    }

    private static Map<String, Object> responseMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testIdentityRejectedWithoutCustomerType() {
        RestResponse res = applyRest('{"email":"orgcontact@example.com"}');

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        System.assertEquals(400, res.statusCode,
            'Section 0 identity must reject payloads with no CustomerType: ' +
            (res.responseBody != null ? res.responseBody.toString() : ''));
    }

    @isTest
    static void testEmptyBodyAfterValidIdentity() {
        RestResponse res = applyRestWithQueryIdentity('');

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('ACC-000', body.get('ErrorCode'));
    }

    @isTest
    static void testNullBodyAfterValidIdentity() {
        RestResponse res = applyRestWithQueryIdentity(null);

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('ACC-000', body.get('ErrorCode'));
    }

    @isTest
    static void testMalformedJsonAfterValidIdentity() {
        // Untyped parse of an array succeeds, so identity from query params stays valid.
        // Typed deserialize into AccountLookupRequestWrapper then throws ACC-001.
        RestResponse res = applyRestWithQueryIdentity('[]');

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(400, res.statusCode);
        System.assertEquals('ACC-001', body.get('ErrorCode'));
    }

    @isTest
    static void testMalformedJsonRejectedAtIdentity() {
        RestResponse res = applyRest('{invalid_json');

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @isTest
    static void testNoSearchCriteria() {
        RestResponse resEmpty = applyRest(lookupPayload(new Map<String, Object>()));
        RestResponse resBlanks;

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Map<String, Object> emptyBody = responseMap(resEmpty);

        resBlanks = applyRest(lookupPayload(new Map<String, Object>{
            'email' => '',
            'mobile' => '   ',
            'emiratesId' => null,
            'tradeLicenseNumber' => ''
        }));
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        System.assertEquals(400, resEmpty.statusCode);
        System.assertEquals('ACC-002', emptyBody.get('ErrorCode'));
        System.assertEquals(400, resBlanks.statusCode);
        System.assertEquals('ACC-002', responseMap(resBlanks).get('ErrorCode'));
    }

    @isTest
    static void testPersonAccountMatchedByEmailMobileAndEid() {
        RestResponse resEmail = applyRest(lookupPayload(new Map<String, Object>{
            'email' => '  ' + PERSON_EMAIL + '  '
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Map<String, Object> emailBody = responseMap(resEmail);

        RestResponse resMobile = applyRest(lookupPayload(new Map<String, Object>{
            'mobile' => PERSON_MOBILE
        }));
        OIC_DPGAccountLookupRestService.searchAccount();
        Map<String, Object> mobileBody = responseMap(resMobile);

        RestResponse resEid = applyRest(lookupPayload(new Map<String, Object>{
            'emiratesId' => PERSON_EID
        }));
        OIC_DPGAccountLookupRestService.searchAccount();
        Map<String, Object> eidBody = responseMap(resEid);
        Test.stopTest();

        System.assertEquals(true, emailBody.get('matchFound'));
        System.assertEquals('Person Account', emailBody.get('accountType'));
        System.assertEquals(true, mobileBody.get('matchFound'));
        System.assertEquals('Person Account', mobileBody.get('accountType'));
        System.assertEquals(true, eidBody.get('matchFound'));
        System.assertEquals('Person Account', eidBody.get('accountType'));
    }

    @isTest
    static void testOrgMatchedByTradeLicenseFallbackContact() {
        RestResponse res = applyRest(lookupPayload(new Map<String, Object>{
            'tradeLicenseNumber' => ORG_TL
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(true, body.get('matchFound'));
        System.assertEquals('Organization Account', body.get('accountType'));
        System.assertNotEquals(null, body.get('contactId'),
            'Fallback should return the account first Contact');
    }

    @isTest
    static void testOrgMatchedByTradeLicenseAndContactEmail() {
        RestResponse res = applyRest(lookupPayload(new Map<String, Object>{
            'tradeLicenseNumber' => ORG_TL,
            'email' => ORG_EMAIL
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(true, body.get('matchFound'));
        System.assertEquals('Organization Account', body.get('accountType'));
        System.assertEquals(ORG_EMAIL, body.get('email'));
    }

    @isTest
    static void testOrgMatchedByTradeLicenseUnmatchedEmailFallsBack() {
        RestResponse res = applyRest(lookupPayload(new Map<String, Object>{
            'tradeLicenseNumber' => ORG_TL,
            'email' => 'nomatch-on-account@example.com'
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(true, body.get('matchFound'));
        System.assertEquals('Organization Account', body.get('accountType'));
        System.assertNotEquals(null, body.get('contactId'));
    }

    @isTest
    static void testOrgMatchedByUnifiedNumberWithNoContact() {
        RestResponse res = applyRest(lookupPayload(new Map<String, Object>{
            'tradeLicenseNumber' => ORG_TL_NO_CON
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(true, body.get('matchFound'));
        System.assertEquals('Organization Account', body.get('accountType'));
        System.assertEquals(null, body.get('contactId'));
    }

    @isTest
    static void testOrgMatchedByContactEmailAndMobile() {
        RestResponse resEmail = applyRest(lookupPayload(new Map<String, Object>{
            'email' => ORG_EMAIL
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Map<String, Object> emailBody = responseMap(resEmail);

        RestResponse resMobile = applyRest(lookupPayload(new Map<String, Object>{
            'mobile' => ORG_MOBILE
        }));
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        System.assertEquals(true, emailBody.get('matchFound'));
        System.assertEquals('Organization Account', emailBody.get('accountType'));
        System.assertEquals(true, responseMap(resMobile).get('matchFound'));
    }

    @isTest
    static void testOrgMatchedByContactPhoneFallbackMobile() {
        RestResponse res = applyRest(lookupPayload(new Map<String, Object>{
            'mobile' => ORG_PHONE
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(true, body.get('matchFound'));
        System.assertEquals('Organization Account', body.get('accountType'));
        System.assertEquals(ORG_PHONE, body.get('mobile'));
    }

    @isTest
    static void testOrgMatchedByUnifiedNumberValue() {
        RestResponse res = applyRest(lookupPayload(new Map<String, Object>{
            'tradeLicenseNumber' => ORG_UNIFIED
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(true, body.get('matchFound'));
        System.assertEquals('Organization Account', body.get('accountType'));
    }

    @isTest
    static void testNoMatchIsSuccessfulSearch() {
        RestResponse res = applyRest(lookupPayload(new Map<String, Object>{
            'email' => 'nonexistent_user@example.com',
            'mobile' => '+971500000000',
            'emiratesId' => '000-0000-0000000-0',
            'tradeLicenseNumber' => 'TL-DOES-NOT-EXIST'
        }));

        Test.startTest();
        OIC_DPGAccountLookupRestService.searchAccount();
        Test.stopTest();

        Map<String, Object> body = responseMap(res);
        System.assertEquals(false, body.get('matchFound'));
        System.assertEquals(true, body.get('success'));
    }
}