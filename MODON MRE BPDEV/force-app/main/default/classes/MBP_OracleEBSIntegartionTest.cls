/**********************************************************************************************************************
 * Name               : MBP_OracleEBSIntegartionTest
 * Description        : Test class for MBP_OracleEBSIntegartion (test class only — no main-class changes).
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Upendra                     2026            Initial happy-path / vendor-not-found coverage.
 * 2.0           Priyanka                    22 09 2026      Raised coverage above 75%. Existing 3 tests passed at
 *                                                           exactly 75% because the else-throw and catch blocks
 *                                                           never ran. Where (this version):
 *                                                           - testReceiveFromOIC_MissingAccountAndVendorId → line 66
 *                                                             (accountId or vendorId is required) + outer catch
 *                                                           - testReceiveFromOIC_MalformedJson → deserialize catch
 *                                                           - testReceiveFromOIC_EmptyBody → deserialize catch
 *                                                           - testReceiveFromOIC_InvalidAccountId → QueryException
 *                                                           - testReceiveFromOIC_UpdateFailsAfterAccountFound →
 *                                                             STRING_TOO_LONG on Text(20) EBS fields after Account
 *                                                             is loaded, so acc != null catch and inner updateEx
 *                                                             catch both run
 **********************************************************************************************************************/
@IsTest
private class MBP_OracleEBSIntegartionTest {

    private static Account createTestAccount() {
        Account acc = new Account(
            Name = 'EBS Test Account',
            OIC_Supplier_Vendor_ID__c = 'VENDOR123'
        );
        insert acc;
        return acc;
    }

    // v2.0 Priyanka 22 09 2026 — shared REST context helper so new negative tests stay small.
    private static void setRestContext(String requestBody) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/ebs';
        request.httpMethod = 'POST';
        if (requestBody != null) {
            request.requestBody = Blob.valueOf(requestBody);
        }
        RestContext.request = request;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void testReceiveFromOIC_ByAccountId() {

        Account acc = createTestAccount();

        MBP_OracleEBSIntegartion.RequestWrapper req =
            new MBP_OracleEBSIntegartion.RequestWrapper();

        req.accountId = acc.Id;
        req.ebsBankBranchPartyId = 'BR001';
        req.ebsBankPartyId = 'BANK001';
        req.ebsVendorAddressId = 'ADDR001';
        req.ebsVendorId = 'VEN001';
        req.ebsVendorPartyId = 'VP001';
        req.ebsVendorSiteId = 'SITE001';
        req.ebsAccountId = 'ACC001';

        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/ebs';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(req));

        RestResponse response = new RestResponse();

        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        MBP_OracleEBSIntegartion.ResponseWrapper res =
            MBP_OracleEBSIntegartion.receiveFromOIC();
        Test.stopTest();

        System.assertEquals('SUCCESS', res.status);

        Account updated =
            [SELECT EBS_SUPPLIER_SYNC_STATUS__c,
                    EBS_BANK_SYNC_STATUS__c
             FROM Account WHERE Id = :acc.Id];

        System.assertEquals('Synced', updated.EBS_SUPPLIER_SYNC_STATUS__c);
    }

    @IsTest
    static void testReceiveFromOIC_ByVendorId() {

        Account acc = createTestAccount();

        MBP_OracleEBSIntegartion.RequestWrapper req =
            new MBP_OracleEBSIntegartion.RequestWrapper();

        req.vendorId = 'VENDOR123';
        req.ebsVendorId = 'VEN002';

        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/ebs';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(req));

        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        MBP_OracleEBSIntegartion.ResponseWrapper res =
            MBP_OracleEBSIntegartion.receiveFromOIC();
        Test.stopTest();

        System.assertEquals('SUCCESS', res.status);
    }

    @IsTest
    static void testReceiveFromOIC_VendorNotFound() {

        MBP_OracleEBSIntegartion.RequestWrapper req =
            new MBP_OracleEBSIntegartion.RequestWrapper();

        req.vendorId = 'NOT_EXIST';

        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/ebs';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(req));

        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        MBP_OracleEBSIntegartion.ResponseWrapper res =
            MBP_OracleEBSIntegartion.receiveFromOIC();
        Test.stopTest();

        System.assertEquals('FAILED', res.status);
        System.assertEquals('No Account found for given VendorId', res.message);
    }

    // v2.0 Priyanka 22 09 2026 — neither accountId nor vendorId throws AuraHandledException (line 66).
    @IsTest
    static void testReceiveFromOIC_MissingAccountAndVendorId() {
        MBP_OracleEBSIntegartion.RequestWrapper req =
            new MBP_OracleEBSIntegartion.RequestWrapper();
        setRestContext(JSON.serialize(req));

        Test.startTest();
        MBP_OracleEBSIntegartion.ResponseWrapper res =
            MBP_OracleEBSIntegartion.receiveFromOIC();
        Test.stopTest();

        System.assertEquals('ERROR', res.status);
        System.assertNotEquals(null, res.message);
    }

    // v2.0 Priyanka 22 09 2026 — malformed body hits the outer catch (acc is still null).
    @IsTest
    static void testReceiveFromOIC_MalformedJson() {
        setRestContext('{not-valid-json');

        Test.startTest();
        MBP_OracleEBSIntegartion.ResponseWrapper res =
            MBP_OracleEBSIntegartion.receiveFromOIC();
        Test.stopTest();

        System.assertEquals('ERROR', res.status);
        System.assertNotEquals(null, res.message);
    }

    // v2.0 Priyanka 22 09 2026 — empty body also hits JSON deserialize catch.
    @IsTest
    static void testReceiveFromOIC_EmptyBody() {
        setRestContext('');

        Test.startTest();
        MBP_OracleEBSIntegartion.ResponseWrapper res =
            MBP_OracleEBSIntegartion.receiveFromOIC();
        Test.stopTest();

        System.assertEquals('ERROR', res.status);
        System.assertNotEquals(null, res.message);
    }

    // v2.0 Priyanka 22 09 2026 — unknown Account Id throws QueryException before acc is assigned.
    @IsTest
    static void testReceiveFromOIC_InvalidAccountId() {
        MBP_OracleEBSIntegartion.RequestWrapper req =
            new MBP_OracleEBSIntegartion.RequestWrapper();
        req.accountId = '001000000000000AAA';
        setRestContext(JSON.serialize(req));

        Test.startTest();
        MBP_OracleEBSIntegartion.ResponseWrapper res =
            MBP_OracleEBSIntegartion.receiveFromOIC();
        Test.stopTest();

        System.assertEquals('ERROR', res.status);
        System.assertNotEquals(null, res.message);
    }

    // v2.0 Priyanka 22 09 2026 — Account is found, then DML fails because EBS Text fields are length 20.
    // The in-memory Account still holds the long value, so the catch update also fails (inner catch).
    @IsTest
    static void testReceiveFromOIC_UpdateFailsAfterAccountFound() {
        Account acc = createTestAccount();

        MBP_OracleEBSIntegartion.RequestWrapper req =
            new MBP_OracleEBSIntegartion.RequestWrapper();
        req.accountId = acc.Id;
        req.ebsBankBranchPartyId = 'THIS-VALUE-IS-LONGER-THAN-TWENTY-CHARS';
        req.ebsBankPartyId = 'THIS-VALUE-IS-LONGER-THAN-TWENTY-CHARS';
        req.ebsVendorId = 'THIS-VALUE-IS-LONGER-THAN-TWENTY-CHARS';
        req.ebsAccountId = 'THIS-VALUE-IS-LONGER-THAN-TWENTY-CHARS';
        setRestContext(JSON.serialize(req));

        Test.startTest();
        MBP_OracleEBSIntegartion.ResponseWrapper res =
            MBP_OracleEBSIntegartion.receiveFromOIC();
        Test.stopTest();

        System.assertEquals('ERROR', res.status);
        System.assertNotEquals(null, res.message);
    }
}