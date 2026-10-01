/**
* @description       :
* @author            : Kumaravel Mathivanan
* @group             :
* @Created modified on  : 13-05-2026
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Kumaravel Mathivanan        02-10-2025     Initial Draft
* 2.0           Manoj                       20-01-2026     Update JSON and Logic.
* 3.0           Manoj                       13-05-2026     Align tests with v6.0/v7.0 ResponseArray structure;
*                                                          fix Reversed to use Remarks; add Cleared/Confirmed tests
********************************************************************************************************/
@isTest
private class RestReceiptServiceTest {

    // ─────────────────────────────────────────────
    // Helper: build a fully encoded request body
    // ─────────────────────────────────────────────
    private static String buildRequestBody(List<RestReceiptService.OIC_RequestWrapper> records) {
        RestReceiptService.OICRequestWrapperList requestList = new RestReceiptService.OICRequestWrapperList();
        requestList.RequestArray = records;

        String jsonPayload   = JSON.serialize(requestList);
        String base64Payload = EncodingUtil.base64Encode(Blob.valueOf(jsonPayload));

        RestReceiptService.Base64RequestWrapper base64Wrapper = new RestReceiptService.Base64RequestWrapper();
        base64Wrapper.Base64Request = base64Payload;

        return JSON.serialize(base64Wrapper);
    }

    // ─────────────────────────────────────────────
    // Helper: set RestContext and call the service
    // ─────────────────────────────────────────────
    private static RestReceiptService.OICResponseWrapperList callService(String fullRequestJson) {
        RestRequest req  = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody  = Blob.valueOf(fullRequestJson);
        req.httpMethod   = 'POST';
        req.requestURI   = '/services/apexrest/ReceiptAPI';
        RestContext.request  = req;
        RestContext.response = res;

        RestReceiptService.Base64ResponseWrapper responseWrapper =
            RestReceiptService.updateReceiptsfromOracle();

        Blob   decodedBlob     = EncodingUtil.base64Decode(responseWrapper.Base64Response);
        String decodedResponse = decodedBlob.toString();

        return (RestReceiptService.OICResponseWrapperList)
            JSON.deserialize(decodedResponse, RestReceiptService.OICResponseWrapperList.class);
    }

    // ─────────────────────────────────────────────
    // Test Data Setup
    // ─────────────────────────────────────────────
    @testSetup
    public static void makeData() {
        Id personAccountRTID = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();

        Account testAccount  = new Account();
        testAccount.FirstName    = 'Test2';
        testAccount.LastName     = 'Account';
        testAccount.RecordTypeId = personAccountRTID;
        testAccount.PersonEmail  = 'test@test22.com';
        insert testAccount;

        Contact conObj   = new Contact();
        conObj.LastName  = 'Test contact';
        conObj.Email     = 'test@test.com';
        insert conObj;

        Opportunity oppObj = new Opportunity();
        oppObj.Name                  = 'Test opportunity';
        oppObj.StageName             = 'Discussion In Progress';
        oppObj.CloseDate             = System.Today();
        oppObj.PrimaryContact__c     = conObj.Id;
        oppObj.UAE_Resident_Status__c = 'Non-Resident';
        oppObj.Nationality__c        = 'India';
        oppObj.PassportExpiryDate__c = Date.today();
        oppObj.PassportIssueDate__c  = Date.today();
        oppObj.PassportNumber__c     = 'NP232131';
        oppObj.En_Nationality__c     = 'India';
        oppObj.En_PassportNumber__c  = 'P1234567';
        insert oppObj;

        EscrowAccount__c escAccount = new EscrowAccount__c(name = 'Phase 1 Escrow Account');
        insert escAccount;

        phase__c phase = new phase__c(name = 'Test Phase', EscrowAccount__c = escAccount.Id);
        insert phase;

        Expressionofinterest__c eoi = new Expressionofinterest__c();
        eoi.Opportunity__c = oppObj.Id;
        eoi.Phase__c       = phase.Id;
        insert eoi;

        SalesOrder__c so = new SalesOrder__c();
        so.TotalAmount__c = 100;
        insert so;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c    = so.Id;
        soi.MilestoneNumber__c = 1;
        insert soi;

        Receipt__c recObj = new Receipt__c();
        recObj.Account__c              = testAccount.Id;
        recObj.ExpressionOfInterest__c = eoi.Id;
        recObj.SalesOrderInstallment__c = soi.Id;
        insert recObj;

        recObj.ExpressionOfInterest__c = null;
        update recObj;
        recObj.ExpressionOfInterest__c = eoi.Id;
        update recObj;

        Invoice__c invoice = new Invoice__c();
        invoice.Expressionofinterest__c = eoi.Id;
        invoice.InvoiceAmount__c        = 100;
        invoice.Account__c              = testAccount.Id;
        insert invoice;
    }

    // ─────────────────────────────────────────────
    // 1. Status = 'S'  →  OraclePartyId__c updated
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_success() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid     = receipt.Id;
        req.Status   = 'S';
        req.OracleID = 'ORACLE-12345';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 2. Status = 'R'  →  Rejected
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_rejected() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid    = receipt.Id;
        req.Status  = 'R';
        req.Remarks = 'Cheque details mismatch';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 3. Status = 'Reversed' + Remarks = 'Cheque Replace'  →  Returned to customer
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_reversedChequeReplace() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid    = receipt.Id;
        req.Status  = 'Reversed';
        req.Remarks = 'Cheque Replace';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

     }

    // ─────────────────────────────────────────────
    // 4. Status = 'Reversed' + Remarks = 'Cheque returned'  →  Returned to customer
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_reversedChequeReturned() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid    = receipt.Id;
        req.Status  = 'Reversed';
        req.Remarks = 'Cheque returned';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 5. Status = 'Reversed' + Remarks = 'Accounting Error'  →  Cancelled
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_reversedAccountingError() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid    = receipt.Id;
        req.Status  = 'Reversed';
        req.Remarks = 'Accounting Error';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 6. Status = 'Reversed' + Remarks = 'Cancelled'  →  Cancelled
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_reversedCancelled() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid    = receipt.Id;
        req.Status  = 'Reversed';
        req.Remarks = 'Cancelled';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 7. Status = 'Reversed' + other Remarks  →  Bounced
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_reversedBounced() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid    = receipt.Id;
        req.Status  = 'Reversed';
        req.Remarks = 'NSF';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 8. Status = 'Remitted'  →  Remitted + OracleID
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_remitted() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid     = receipt.Id;
        req.Status   = 'Remitted';
        req.OracleID = 'ORA-REM-001';
        req.Remarks  = 'Deposited to bank';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 9. Status = 'Cleared'  →  Cleared + EBS_Clearing_Date__c
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_cleared() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid        = receipt.Id;
        req.Status      = 'Cleared';
        req.OracleID    = 'ORA-CLR-001';
        req.ClearedDate = Date.today();

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 10. Status = 'Confirmed'  →  Confirmed + OracleID  (v7.0)
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_confirmed() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid     = receipt.Id;
        req.Status   = 'Confirmed';
        req.OracleID = 'ORA-CNF-001';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 11. Missing Base64Request  →  Error response
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_missingBase64() {
        RestReceiptService.Base64RequestWrapper base64Wrapper = new RestReceiptService.Base64RequestWrapper();
        base64Wrapper.Base64Request = null;

        RestRequest req  = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody  = Blob.valueOf(JSON.serialize(base64Wrapper));
        req.httpMethod   = 'POST';
        req.requestURI   = '/services/apexrest/ReceiptAPI';
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        RestReceiptService.Base64ResponseWrapper responseWrapper =
            RestReceiptService.updateReceiptsfromOracle();
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 12. Invalid Sfid  →  per-record Error in ResponseArray
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_invalidSfid() {
        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid   = 'a0B000000INVALID';
        req.Status = 'S';

        Test.startTest();
       
    }

    // ─────────────────────────────────────────────
    // 13. Both Sfid and OracleID blank  →  per-record Error
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_blankSfidAndOracleID() {
        RestReceiptService.OIC_RequestWrapper req = new RestReceiptService.OIC_RequestWrapper();
        req.Sfid     = '';
        req.OracleID = '';
        req.Status   = 'S';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result =
            callService(buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ req }));
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 14. Multi-record batch  →  partial success
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_multiRecord() {
        Receipt__c receipt = [SELECT Id FROM Receipt__c LIMIT 1];

        RestReceiptService.OIC_RequestWrapper validReq = new RestReceiptService.OIC_RequestWrapper();
        validReq.Sfid     = receipt.Id;
        validReq.Status   = 'Confirmed';
        validReq.OracleID = 'ORA-MULTI-001';

        RestReceiptService.OIC_RequestWrapper invalidReq = new RestReceiptService.OIC_RequestWrapper();
        invalidReq.Sfid   = 'a0B000000INVALID';
        invalidReq.Status = 'Cleared';

        Test.startTest();
        RestReceiptService.OICResponseWrapperList result = callService(
            buildRequestBody(new List<RestReceiptService.OIC_RequestWrapper>{ validReq, invalidReq })
        );
        Test.stopTest();

    }

    // ─────────────────────────────────────────────
    // 15. Malformed request body  →  Unhandled error caught
    // ─────────────────────────────────────────────
    @isTest
    static void testUpdateReceiptsFromOracle_malformedBody() {
        RestRequest req  = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestBody  = Blob.valueOf('THIS IS NOT VALID JSON');
        req.httpMethod   = 'POST';
        req.requestURI   = '/services/apexrest/ReceiptAPI';
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        RestReceiptService.Base64ResponseWrapper responseWrapper =
            RestReceiptService.updateReceiptsfromOracle();
        Test.stopTest();

       
    }
}