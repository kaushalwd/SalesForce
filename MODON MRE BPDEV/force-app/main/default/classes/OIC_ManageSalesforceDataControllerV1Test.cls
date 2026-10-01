/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceDataControllerV1Test
* Description        : Test Class for desc component OIC_ManageSalesforceDataControllerV1 
* Created By         : Amgs Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj	            10 Oct 2025        Initial Draft
* 2.0           Manoj 				13 Jan 2026		   Update the Fix
***********************************************************************************************************************/
@isTest
public class OIC_ManageSalesforceDataControllerV1Test {

    @TestSetup
    static void setupData() {
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe()
            .get('Account').getDescribe()
            .getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();

        Account accountObj = new Account(RecordTypeId = recordTypeId);
        accountObj.PersonEmail = 'test@test.com';
        accountObj.FirstName   = 'First';
        accountObj.LastName    = 'Last';
        accountObj.OraclePartyId__c = '22212';
        insert accountObj;

        Unit__c unitObj = new Unit__c();
        unitObj.Name                  = 'Test Unit';
        unitObj.BasePrice__c          = 1000;
        unitObj.AdditionalPrice__c    = 0;
        unitObj.PlotAreasqm__c        = 1.0;
        unitObj.PlotNo__c             = '1';
        unitObj.UnitClassification__c = 'Villa';
        unitObj.Number_of_Bedrooms__c = '2';
        insert unitObj;

        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c              = 'In Progress';
        salesOrderObj.Unit__c                = unitObj.Id;
        salesOrderObj.CustomerAccount__c     = accountObj.Id;
        salesOrderObj.TotalAmount__c         = 20000;
        salesOrderObj.OraclePartySiteID__c   = '33333';
        salesOrderObj.OracleCustAcctSiteID__c = '765456';
        salesOrderObj.Source_Entity__c       = 'Modon - UAE';
        insert salesOrderObj;

        SalesOrderInstallments__c soInstallmentObj = new SalesOrderInstallments__c();
        soInstallmentObj.SalesOrder__c    = salesOrderObj.Id;
        soInstallmentObj.Milestone__c     = 1;
        soInstallmentObj.MilestoneNumber__c = 1;
        insert soInstallmentObj;
    }

    // ── MOCK HELPERS ─────────────────────────────────────────────────────────

    /**
     * Builds a base64-wrapped response for any SObject type.
     * statusVal = 'S' or 'E'
     * useSOWrapper = true  → OICSOResponseWrapperList (for Sales Order)
     * useSOWrapper = false → OICResponseWrapperList   (for Account / generic)
     */
    private static HTTPResponse buildResponse(String sfid, String statusVal, Boolean useSOWrapper) {
        String jsonResponse;

        if (useSOWrapper) {
            OIC_RequestWrapperController.OICSOResponseWrapper r =
                new OIC_RequestWrapperController.OICSOResponseWrapper();
            r.Sfid               = sfid;
            r.Status             = statusVal;
            r.ErrorMsg           = statusVal == 'E' ? 'Test error' : null;
            r.OracleId           = statusVal == 'S' ? 'SO-123'     : null;
            r.CustAcctId         = 'CA-001';
            r.OraclePartySiteID  = 'PS-001';
            r.OracleCustAcctSiteID = 'CAS-001';
            r.OracleSiteUseID    = 'SU-001';

            OIC_RequestWrapperController.OICSOResponseWrapperList lst =
                new OIC_RequestWrapperController.OICSOResponseWrapperList();
            lst.ResponseArray = new List<OIC_RequestWrapperController.OICSOResponseWrapper>{ r };
            jsonResponse = JSON.serialize(lst);

        } else {
            OIC_RequestWrapperController.OICResponseWrapper r =
                new OIC_RequestWrapperController.OICResponseWrapper();
            r.Sfid     = sfid;
            r.Status   = statusVal;
            r.ErrorMsg = statusVal == 'E' ? 'Test error' : null;
            r.OracleId = statusVal == 'S' ? 'Test123'   : null;

            OIC_RequestWrapperController.OICResponseWrapperList lst =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            lst.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>{ r };
            jsonResponse = JSON.serialize(lst);
        }

        String base64 = EncodingUtil.base64Encode(Blob.valueOf(jsonResponse));

        OIC_RequestWrapperController.Base64ResponseWrapper b64 =
            new OIC_RequestWrapperController.Base64ResponseWrapper();
        b64.Base64Response = base64;

        HTTPResponse res = new HTTPResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody(JSON.serialize(b64));
        res.setStatusCode(200);
        return res;
    }

    // ── STATUS = S MOCKS ─────────────────────────────────────────────────────

    private class AccountSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            Account acc = [SELECT Id FROM Account LIMIT 1];
            return buildResponse(acc.Id, 'S', false);
        }
    }

    private class SOSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
            return buildResponse(so.Id, 'S', true);
        }
    }

    // ── STATUS = E MOCKS ─────────────────────────────────────────────────────

    private class AccountErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            Account acc = [SELECT Id FROM Account LIMIT 1];
            return buildResponse(acc.Id, 'E', false);
        }
    }

    private class SOErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
            return buildResponse(so.Id, 'E', true);
        }
    }

    // ── EMPTY BODY MOCK (covers null/empty response path) ────────────────────

    private class EmptyBodyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('');
            res.setStatusCode(200);
            return res;
        }
    }

    // ── EXCEPTION MOCK (covers catch blocks) ─────────────────────────────────

    private class ExceptionMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            CalloutException e = (CalloutException) CalloutException.class.newInstance();
            e.setMessage('Simulated callout exception');
            throw e;
        }
    }

    // =========================================================================
    // TEST METHODS
    // =========================================================================

    // ── createAccount: person account, Status = S ────────────────────────────
    @isTest
    static void createAccount_PersonAccount_Success() {
        Set<String> ids = new Set<String>();
        for (Account a : [SELECT Id FROM Account LIMIT 1]) ids.add(a.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountSuccessMock());
        String result = OIC_ManageSalesforceDataControllerV1.createAccount(ids);
        Test.stopTest();
    }

    // ── createAccount: person account, Status = E (covers E branch + retry++) ─
    @isTest
    static void createAccount_PersonAccount_Error() {
        Set<String> ids = new Set<String>();
        for (Account a : [SELECT Id FROM Account LIMIT 1]) ids.add(a.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountErrorMock());
        String result = OIC_ManageSalesforceDataControllerV1.createAccount(ids);
        Test.stopTest();
    }

    // ── createAccount: person account, Status = E with existing retry count ──
    @isTest
    static void createAccount_PersonAccount_Error_WithExistingRetry() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        acc.OICNoOfRetries__c = 2;
        TriggerControl.BypassAccountTrigger = true;
        update acc;
        TriggerControl.BypassAccountTrigger = false;

        Set<String> ids = new Set<String>{ acc.Id };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountErrorMock());
        OIC_ManageSalesforceDataControllerV1.createAccount(ids);
        Test.stopTest();

    }

    // ── createAccount: org (non-person) account ──────────────────────────────
    @isTest
    static void createAccount_OrgAccount_Success() {
        Account orgAcc = new Account();
        orgAcc.Name             = 'Test Org Account';
        orgAcc.Source_Entity__c = 'Modon - UAE';
        insert orgAcc;

        Set<String> ids = new Set<String>{ orgAcc.Id };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountSuccessMock());
        String result = OIC_ManageSalesforceDataControllerV1.createAccount(ids);
        Test.stopTest();

        // Org account goes through createOrganizationWrapper — just verify no exception
        System.assertNotEquals(null, result);
    }

    // ── createAccount: empty response body (covers null body path) ───────────
    @isTest
    static void createAccount_EmptyResponse() {
        Set<String> ids = new Set<String>();
        for (Account a : [SELECT Id FROM Account LIMIT 1]) ids.add(a.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new EmptyBodyMock());
        String result = OIC_ManageSalesforceDataControllerV1.createAccount(ids);
        Test.stopTest();

    }

    // ── createAccount: callout exception → catch block ───────────────────────
    @isTest
    static void createAccount_CalloutException() {
        Set<String> ids = new Set<String>();
        for (Account a : [SELECT Id FROM Account LIMIT 1]) ids.add(a.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        String result = OIC_ManageSalesforceDataControllerV1.createAccount(ids);
        Test.stopTest();
    }

    // ── createAccount: Source_Entity__c exclusion filter ─────────────────────
    @isTest
    static void createAccount_ExcludedSourceEntity() {
        Schema.RecordTypeInfo rt = Schema.getGlobalDescribe()
            .get('Account').getDescribe()
            .getRecordTypeInfosByDeveloperName().get('PersonAccount');
        Account excludedAcc = new Account(RecordTypeId = rt.getRecordTypeId());
        excludedAcc.FirstName       = 'Egypt';
        excludedAcc.LastName        = 'Test';
        excludedAcc.PersonEmail     = 'egypt@test.com';
        excludedAcc.Source_Entity__c = 'Modon - Egypt';
        insert excludedAcc;

        Set<String> ids = new Set<String>{ excludedAcc.Id };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountSuccessMock());
        // SOQL filters this out — callout still happens but with empty list
        String result = OIC_ManageSalesforceDataControllerV1.createAccount(ids);
        Test.stopTest();

    }

    // ── createSalesOrderAndSOInstallments: Status = S ────────────────────────
    @isTest
    static void createSO_Success() {
        Set<String> ids = new Set<String>();
        for (SalesOrder__c so : [SELECT Id FROM SalesOrder__c LIMIT 5]) ids.add(so.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SOSuccessMock());
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        String result = OIC_ManageSalesforceDataControllerV1.createSalesOrderAndSOInstallments(ids);
        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        Test.stopTest();

    }

    // ── createSalesOrderAndSOInstallments: Status = E ────────────────────────
    @isTest
    static void createSO_Error() {
        Set<String> ids = new Set<String>();
        for (SalesOrder__c so : [SELECT Id FROM SalesOrder__c LIMIT 5]) ids.add(so.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SOErrorMock());
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        String result = OIC_ManageSalesforceDataControllerV1.createSalesOrderAndSOInstallments(ids);
        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        Test.stopTest();

    }

    // ── createSalesOrderAndSOInstallments: Status = E with existing retry ────
    @isTest
    static void createSO_Error_WithExistingRetry() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.OICNoOfRetries__c = 3;
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        update so;
        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;

        Set<String> ids = new Set<String>{ so.Id };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SOErrorMock());
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        OIC_ManageSalesforceDataControllerV1.createSalesOrderAndSOInstallments(ids);
        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        Test.stopTest();

    }

    // ── createSalesOrderAndSOInstallments: PropertyTransfer branch ────────────
    @isTest
    static void createSO_PropertyTransfer() {
        Account acc = [SELECT Id FROM Account WHERE OraclePartyId__c = '22212' LIMIT 1];

        // Create a second account to act as the old account
        Schema.RecordTypeInfo rt = Schema.getGlobalDescribe()
            .get('Account').getDescribe()
            .getRecordTypeInfosByDeveloperName().get('PersonAccount');
        Account oldAcc = new Account(RecordTypeId = rt.getRecordTypeId());
        oldAcc.FirstName = 'Old';
        oldAcc.LastName  = 'Owner';
        oldAcc.PersonEmail = 'old@test.com';
        oldAcc.OraclePartyId__c = '99999';
        insert oldAcc;

        // Set Old_Account__c on the existing Sales Order to hit PropertyTransfer = 'Y'
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.Old_Account__c = oldAcc.Id;
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        update so;
        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;

        Set<String> ids = new Set<String>{ so.Id };

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SOSuccessMock());
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        String result = OIC_ManageSalesforceDataControllerV1.createSalesOrderAndSOInstallments(ids);
        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        Test.stopTest();

    }

    // ── createSalesOrderAndSOInstallments: empty response body ───────────────
    @isTest
    static void createSO_EmptyResponse() {
        Set<String> ids = new Set<String>();
        for (SalesOrder__c so : [SELECT Id FROM SalesOrder__c LIMIT 1]) ids.add(so.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new EmptyBodyMock());
        String result = OIC_ManageSalesforceDataControllerV1.createSalesOrderAndSOInstallments(ids);
        Test.stopTest();

    }

    // ── createSalesOrderAndSOInstallments: callout exception ─────────────────
    @isTest
    static void createSO_CalloutException() {
        Set<String> ids = new Set<String>();
        for (SalesOrder__c so : [SELECT Id FROM SalesOrder__c LIMIT 1]) ids.add(so.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        String result = OIC_ManageSalesforceDataControllerV1.createSalesOrderAndSOInstallments(ids);
        Test.stopTest();

    }

    // ── updateUnitStatus: normal path ────────────────────────────────────────
    @isTest
    static void updateUnitStatus_Success() {
        Set<String> ids = new Set<String>();
        for (Unit__c u : [SELECT Id FROM Unit__c LIMIT 5]) ids.add(u.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountSuccessMock());
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;
        OIC_ManageSalesforceDataControllerV1.updateUnitStatus(ids);
        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        Test.stopTest();

    }

    // ── updateUnitStatus: empty set (boundary) ───────────────────────────────
    @isTest
    static void updateUnitStatus_EmptySet() {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AccountSuccessMock());
        OIC_ManageSalesforceDataControllerV1.updateUnitStatus(new Set<String>());
        Test.stopTest();

    }
}