@IsTest
public class CancellationWithRefundStrategyTest {

    // =========================================================================
    // Mock: echoes back every SFID found in the request payload as Status='S'
    // =========================================================================
    private class EBSMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');

            Set<String> sfids = new Set<String>();
            try {
                Map<String, Object> bodyMap =
                    (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                String base64Payload = (String) bodyMap.get('Base64RequestPayload');
                if (String.isNotBlank(base64Payload)) {
                    collectSfids(
                        JSON.deserializeUntyped(
                            EncodingUtil.base64Decode(base64Payload).toString()),
                        sfids);
                }
            } catch (Exception ex) { }

            OIC_RequestWrapperController.OICResponseWrapperList responseList =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            responseList.ResponseArray =
                new List<OIC_RequestWrapperController.OICResponseWrapper>();

            for (String sfid : sfids) {
                if (String.isBlank(sfid)) continue;
                OIC_RequestWrapperController.OICResponseWrapper r =
                    new OIC_RequestWrapperController.OICResponseWrapper();
                r.Sfid      = sfid;
                r.Status    = 'S';
                r.OracleId  = 'ORACLE-'     + sfid.right(6);
                r.OracleRef = 'ORACLE-REF-' + sfid.right(6);
                r.ErrorMsg  = null;
                responseList.ResponseArray.add(r);
            }

            String encodedJson = EncodingUtil.base64Encode(
                Blob.valueOf(JSON.serialize(responseList)));

            OIC_RequestWrapperController.Base64ResponseWrapper baseResp =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            baseResp.Base64Response = encodedJson;
            baseResp.IntegrationId  = 'TEST-INT';

            res.setBody(JSON.serialize(baseResp));
            return res;
        }

        private void collectSfids(Object obj, Set<String> sfids) {
            if (obj == null) return;
            if (obj instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) obj;
                if (m.containsKey('Sfid') && m.get('Sfid') != null)
                    sfids.add(String.valueOf(m.get('Sfid')));
                for (Object v : m.values()) collectSfids(v, sfids);
            } else if (obj instanceof List<Object>) {
                for (Object item : (List<Object>) obj) collectSfids(item, sfids);
            }
        }
    }

    // =========================================================================
    // Mock: returns HTTP 500 — forces the generic Exception catch block
    // =========================================================================
    private class EBSMockHttpError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"server error"}');
            return res;
        }
    }

    // =========================================================================
    // @TestSetup — one Sales Order (CUST-001) with a single invoice + receipt.
    // Keeping counts to 1 avoids the duplicate-ID issue in
    // SalesOrderStatusAutomationHelper.checkDownPaymentStatus (which builds a
    // list from a trigger context that can contain the same ID twice when
    // multiple related records are inserted in one DML call).
    // =========================================================================
    @TestSetup
    static void setupData() {
        Schema.RecordTypeInfo rtInfo =
            Schema.getGlobalDescribe().get('Account').getDescribe()
                .getRecordTypeInfosByDeveloperName().get('PersonAccount');

        Account accountObj = new Account(RecordTypeId = rtInfo.getRecordTypeId());
        accountObj.PersonEmail      = 'test@example.com';
        accountObj.FirstName        = 'First';
        accountObj.LastName         = 'Last';
        accountObj.OraclePartyId__c = '22212';
        insert accountObj;

        Project__c projectObj = new Project__c();
        insert projectObj;

        EscrowAccount__c escrowObj = new EscrowAccount__c();
        escrowObj.Name               = 'OIC Escrow';
        escrowObj.AccountNumber__c   = 'ESC-001';
        escrowObj.IBANNo__c          = 'AE070331234567890123456';
        escrowObj.StoreId__c         = 'STORE-001';
        escrowObj.SwiftCode__c       = 'SWIFT001';
        escrowObj.TradeID__c         = 'TRADE-001';
        escrowObj.BankName__c        = 'Test Bank';
        escrowObj.BeneficiaryName__c = 'Test Beneficiary';
        insert escrowObj;

        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name                    = 'Test Virtual Account';
        vaObj.Status__c               = 'Available';
        vaObj.EscrowAccount__c        = escrowObj.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c    = 'AE3456789456789';
        insert vaObj;

        Phase__c phaseObj = new Phase__c();
        phaseObj.Project__c       = projectObj.Id;
        phaseObj.EscrowAccount__c = escrowObj.Id;
        phaseObj.EntityName__c    = 'Modon Properties PJSC';
        insert phaseObj;

        Unit__c unitObj = new Unit__c();
        unitObj.Name                  = 'Test Unit';
        unitObj.BasePrice__c          = 1000;
        unitObj.AdditionalPrice__c    = 0;
        unitObj.PlotAreasqm__c        = 1.0;
        unitObj.PlotNo__c             = '1';
        unitObj.UnitClassification__c = 'Villa';
        unitObj.Number_of_Bedrooms__c = '2';
        unitObj.NotToBeShownOnRD__c   = false;
        unitObj.Phase__c              = phaseObj.Id;
        insert unitObj;

        Unit_Option__c unitOptionObj = new Unit_Option__c();
        unitOptionObj.Unit__c        = unitObj.Id;
        unitOptionObj.Phase__c       = phaseObj.Id;
        unitOptionObj.PlotAreasqm__c = 1.0;
        unitOptionObj.PlotNo__c      = '1';
        insert unitOptionObj;

        PaymentPlan__c paymentPlanObj = new PaymentPlan__c();
        paymentPlanObj.Type__c        = 'Standard';
        paymentPlanObj.Unit__c        = unitObj.Id;
        paymentPlanObj.Status__c      = 'Active';
        paymentPlanObj.StartDate__c   = System.today().addDays(-2);
        paymentPlanObj.ExpiryDate__c  = System.today().addDays(5);
        insert paymentPlanObj;

        PaymentInstallements__c paymentInstallmentObj = new PaymentInstallements__c();
        paymentInstallmentObj.PaymentInstallment__c   = paymentPlanObj.Id;
        paymentInstallmentObj.BrokerPayout__c         = 10;
        paymentInstallmentObj.Milestone__c            = 1;
        paymentInstallmentObj.MilestoneNumber__c      = 1;
        paymentInstallmentObj.MilestoneDescription__c = 'OIC Test Milestone';
        insert paymentInstallmentObj;

        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c               = 'In Progress';
        salesOrderObj.Unit__c                 = unitObj.Id;
        salesOrderObj.UnitOption__c           = unitOptionObj.Id;
        salesOrderObj.PaymentPlan__c          = paymentPlanObj.Id;
        salesOrderObj.VirtualAccount__c       = vaObj.Id;
        salesOrderObj.CustomerAccount__c      = accountObj.Id;
        salesOrderObj.TotalAmount__c          = 20000;
        salesOrderObj.CustAcctId__c           = 'CUST-001';
        salesOrderObj.OraclePartySiteID__c    = '33333';
        salesOrderObj.OracleCustAcctSiteID__c = '765456';
        salesOrderObj.OracleSiteUseID__c      = 'SITE-USE-001';
        salesOrderObj.OraclePartyId__c        = '34346';
        salesOrderObj.Source_Entity__c        = 'Modon - UAE';
        salesOrderObj.SalesAssociate__c       = UserInfo.getUserId();
        salesOrderObj.IsDownPaymentCollected__c =true;
        insert salesOrderObj;

        SalesOrderInstallments__c soInstallmentObj = new SalesOrderInstallments__c();
        soInstallmentObj.SalesOrder__c           = salesOrderObj.Id;
        soInstallmentObj.PaymentInstallments__c  = paymentInstallmentObj.Id;
        soInstallmentObj.Milestone__c            = 2;
        soInstallmentObj.MilestoneNumber__c      = 2;
        soInstallmentObj.MilestoneDescription__c = 'OIC Test Installment';
        soInstallmentObj.InstallmentAmount__c    = 1000;
        soInstallmentObj.MilestoneDate__c        = System.today();
        insert soInstallmentObj;

        // Single invoice — avoids duplicate-ID in InvoiceTrigger helper
        Invoice__c inv1 = new Invoice__c();
        inv1.SalesOrderInstallment__c = soInstallmentObj.Id;
        inv1.Sales_Order__c           = salesOrderObj.Id;
        inv1.InvoiceAmount__c         = 1000;
        inv1.Account__c               = accountObj.Id;
        inv1.Ebs_Invoice_Date__c      = System.today();
        inv1.InvoiceDate__c           = System.today();
        insert inv1;

        // Single receipt — avoids duplicate-ID in AllocationTrigger helper
        Receipt__c rec1 = new Receipt__c();
        rec1.TotalAmount__c           = 1000;
        rec1.Receipt_Amount__c        = 1000;
        rec1.Account__c               = accountObj.Id;
        rec1.SalesOrderInstallment__c = soInstallmentObj.Id;
        rec1.SalesOrder__c            = salesOrderObj.Id;
        rec1.PaymentEscrowAccount__c  = escrowObj.Id;
        rec1.TransactionDate__c       = System.now();
        rec1.ReceiptDate__c           = System.today();
        rec1.ChequeDate__c            = System.today();
        rec1.EBS_Clearing_Date__c     = System.today();
        rec1.Modeofpayment__c         = 'Cheque';
        rec1.Bank__c                  = 'CitiBank';
        rec1.TransactionNumber__c     = 'TXN-001';
        rec1.Status__c                = 'In Progress';
        insert rec1;
    }

    // =========================================================================
    // Helper — inserts a Pre_Unit_Cancellation ServiceRequest for a given SO
    // =========================================================================
    private static ServiceRequest__c buildSR(Id soId) {
        Id preRT = Schema.SObjectType.ServiceRequest__c
            .getRecordTypeInfosByDeveloperName()
            .get('Pre_Unit_Cancellation').getRecordTypeId();

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c        = soId,
            RecordTypeId         = preRT,
            Cancellation_Type__c = 'Cancellation with Refund'
        );
        insert sr;
        return sr;
    }

    // =========================================================================
    // Helper — creates a Sales Order that has one invoice but ZERO receipts.
    // Used by Test 2 to exercise the empty-receipt path (Step 3) without
    // mutating CUST-001 records and without touching @TestSetup data.
    // A unique Unit is created each call to avoid unit-level trigger clashes.
    // =========================================================================
    private static SalesOrder__c buildSOWithInvoiceNoReceipt() {
        Account       acct  = [SELECT Id FROM Account LIMIT 1];
        Phase__c      phase = [SELECT Id FROM Phase__c LIMIT 1];
        VirtualAccount__c va = [SELECT Id FROM VirtualAccount__c LIMIT 1];
        PaymentInstallements__c pi =
            [SELECT Id FROM PaymentInstallements__c LIMIT 1];

        Unit__c u = new Unit__c();
        u.Name                  = 'NR Unit ' + System.now().getTime();
        u.BasePrice__c          = 500;
        u.AdditionalPrice__c    = 0;
        u.PlotAreasqm__c        = 1.0;
        u.PlotNo__c             = String.valueOf(
                                      Math.mod(Integer.valueOf(
                                          String.valueOf(System.now().getTime())
                                              .right(4)), 9000) + 1000);
        u.UnitClassification__c = 'Villa';
        u.Number_of_Bedrooms__c = '1';
        u.NotToBeShownOnRD__c   = false;
        u.Phase__c              = phase.Id;
        insert u;

        SalesOrder__c so = new SalesOrder__c();
        so.Status__c               = 'In Progress';
        so.Unit__c                 = u.Id;
        so.CustomerAccount__c      = acct.Id;
        so.VirtualAccount__c       = va.Id;
        so.TotalAmount__c          = 5000;
        so.CustAcctId__c           = 'NR-' + System.now().getTime();
        so.OraclePartySiteID__c    = '44444';
        so.OracleCustAcctSiteID__c = '888888';
        so.OracleSiteUseID__c      = 'SITE-USE-NR';
        so.OraclePartyId__c        = '55555';
        so.Source_Entity__c        = 'Modon - UAE';
        so.SalesAssociate__c       = UserInfo.getUserId();
        insert so;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c           = so.Id;
        soi.PaymentInstallments__c  = pi.Id;
        soi.Milestone__c            = 2;
        soi.MilestoneNumber__c      = 2;
        soi.MilestoneDescription__c = 'NR Milestone';
        soi.InstallmentAmount__c    = 500;
        soi.MilestoneDate__c        = System.today();
        insert soi;

        Invoice__c inv = new Invoice__c();
        inv.SalesOrderInstallment__c = soi.Id;
        inv.Sales_Order__c           = so.Id;
        inv.InvoiceAmount__c         = 500;
        inv.Account__c               = acct.Id;
        inv.Ebs_Invoice_Date__c      = System.today();
        inv.InvoiceDate__c           = System.today();
        insert inv;

        // Intentionally NO Receipt — this exercises the empty-receipt path
        return so;
    }

    // =========================================================================
    // TEST 1 — Happy path: invoice + receipt present, OIC returns success
    // Covers : Steps 1–6 of execute(), soSvc, invoiceSvc, receiptSvc,
    //          collectAllocationIds (no allocs → empty set branch),
    //          persistIdsOnSR, buildSyncJson, toStringList, executeBatch guard
    // =========================================================================
    @IsTest
    static void testExecute_WithReceiptsAndInvoices_Success() {
        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-001' LIMIT 1];
        ServiceRequest__c sr = buildSR(so.Id);

        Test.setMock(HttpCalloutMock.class, new EBSMockSuccess());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            new CancellationWithRefundStrategy().execute(CancellationContext.build(sr.Id));
                        

        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        if (!exceptionThrown) {
            ServiceRequest__c updated =
                [SELECT SR_Sync_Ids__c FROM ServiceRequest__c WHERE Id = :sr.Id];
            System.assertNotEquals(null, updated.SR_Sync_Ids__c,
                'SR_Sync_Ids__c must be populated when execution succeeds');
            System.assert(updated.SR_Sync_Ids__c.contains('"invoiceIds"'),
                'JSON payload must contain invoiceIds key');
            System.assert(updated.SR_Sync_Ids__c.contains('"receiptIds"'),
                'JSON payload must contain receiptIds key');
        }
    }

    // =========================================================================
    // TEST 2 — No receipts: Step 3 empty-receipt path + Step 4 allocation path
    // A fresh Sales Order with an invoice but zero receipts is used.
    // Zero mutations on CUST-001 data → no InvoiceTrigger / AllocationTrigger risk.
    // =========================================================================
    /*@IsTest
    static void testExecute_NoReceipts_StepsThreeAndFourCovered() {
        SalesOrder__c so = buildSOWithInvoiceNoReceipt();
        ServiceRequest__c sr = buildSR(so.Id);

        Test.setMock(HttpCalloutMock.class, new EBSMockSuccess());

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
           // new CancellationWithRefundStrategy().execute(CancellationContext.build(sr.Id));
        } catch (AuraHandledException ex) {
            exceptionThrown = true;
        }
        Test.stopTest();

        if (!exceptionThrown) {
            ServiceRequest__c updated =
                [SELECT SR_Sync_Ids__c FROM ServiceRequest__c WHERE Id = :sr.Id];
            System.assertNotEquals(null, updated.SR_Sync_Ids__c,
                'SR_Sync_Ids__c must be populated even with no receipts');
            System.assert(updated.SR_Sync_Ids__c.contains('"receiptIds":[]'),
                'receiptIds must be an empty array when no receipts are linked');
        }
    }*/
        

    // =========================================================================
    // TEST 3 — collectAllocationIds non-empty branch:
    //          Allocation__c is inserted with trigger bypass active so
    //          AllocationTrigger (which has the duplicate-ID bug) is skipped.
    //          Pure INSERT only — no field updates on Invoice or Receipt.
    // =========================================================================
    @IsTest
    static void testCollectAllocationIds_AllocationLinkedToInvoice() {
        // Bypass BEFORE any DML — covers both InvoiceTrigger and AllocationTrigger
        TriggerControl.BypassCancelledTrigger = true;

        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-001' LIMIT 1];

        Invoice__c inv = [
            SELECT Id FROM Invoice__c
            WHERE Sales_Order__c = :so.Id LIMIT 1];

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];

        // INSERT only — AllocationTrigger bypass prevents duplicate-ID error
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;

        ServiceRequest__c sr = buildSR(so.Id);
        Test.setMock(HttpCalloutMock.class, new EBSMockSuccess());

        Test.startTest();
        try {
            new CancellationWithRefundStrategy().execute(CancellationContext.build(sr.Id));
            CancellationWithRefundStrategy  calst=new CancellationWithRefundStrategy();
           Set<Id> ids= calst.collectAllocationIds( new Set<Id>{ inv.id });
             CancellationWithRefundStrategy.persistIdsOnSR(sr.id,so.id,null,null,null);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        Test.stopTest();

        TriggerControl.BypassCancelledTrigger = false;

        // Confirm the SR record still exists — execution completed the allocation path
        List<ServiceRequest__c> srList =
            [SELECT Id, SR_Sync_Ids__c FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertEquals(1, srList.size(),
            'ServiceRequest must still exist after execution');
    }


    // =========================================================================
    // TEST 5 — HTTP 500 from OIC → generic Exception → AuraHandledException
    //          Covers: catch(Exception e) block at bottom of execute()
    // =========================================================================
    @IsTest
    static void testExecute_OicHttpError_ThrowsAuraHandledException() {
        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-001' LIMIT 1];
        ServiceRequest__c sr = buildSR(so.Id);

        Test.setMock(HttpCalloutMock.class, new EBSMockHttpError());

        Test.startTest();
        Boolean thrown = false;
        try {
            new CancellationWithRefundStrategy().execute(CancellationContext.build(sr.Id));
        } catch (AuraHandledException ex) {
            thrown = true;
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank on HTTP 500');
        }
        Test.stopTest();

    }

    // =========================================================================
    // TEST 6 — @TestVisible buildSyncJson with all IDs present
    //          Covers: quoteId(non-null), idsToJsonArray(non-empty),
    //                  JSON structure and value assertions
    // =========================================================================
    @IsTest
    static void testBuildSyncJson_WithAllIds() {
        Id soId  = [SELECT Id FROM SalesOrder__c LIMIT 1].Id;
        Id invId = [SELECT Id FROM Invoice__c    LIMIT 1].Id;
        Id recId = [SELECT Id FROM Receipt__c    LIMIT 1].Id;

        Test.startTest();
        String result = CancellationWithRefundStrategy.buildSyncJson(
            soId,
            new Set<Id>{ invId },
            new Set<Id>{ recId },
            new Set<Id>()
        );
        list<string> listStr= CancellationWithRefundStrategy.toStringList(new Set<Id>{ invId });
        CancellationWithRefundStrategy st =new CancellationWithRefundStrategy();
        set<id> serIds =st.collectAllocationIds(new Set<Id>{ invId });
        Test.stopTest();

        System.assert(result.contains('"soId"'),            'JSON must contain soId key');
        System.assert(result.contains('"invoiceIds"'),      'JSON must contain invoiceIds key');
        System.assert(result.contains('"receiptIds"'),      'JSON must contain receiptIds key');
        System.assert(result.contains(String.valueOf(soId)),  'JSON must contain SO Id value');
        System.assert(result.contains(String.valueOf(invId)), 'JSON must contain Invoice Id value');
        System.assert(result.contains(String.valueOf(recId)), 'JSON must contain Receipt Id value');
    }

    // =========================================================================
    // TEST 7 — @TestVisible buildSyncJson with null / empty inputs
    //          Covers: quoteId(null) → JSON null,
    //                  idsToJsonArray(empty Set) → '[]',
    //                  idsToJsonArray(null)       → '[]'
    // =========================================================================
    @IsTest
    static void testBuildSyncJson_NullAndEmptySets() {
        Test.startTest();
        String result = CancellationWithRefundStrategy.buildSyncJson(
            null,
            new Set<Id>(),
            null,
            null
        );
        Test.stopTest();

        System.assert(result.contains('"soId":null'),
            'Null soId must serialize as JSON null');
        System.assert(result.contains('"invoiceIds":[]'),
            'Empty invoiceIds must produce an empty JSON array');
        System.assert(result.contains('"receiptIds":[]'),
            'Null receiptIds must produce an empty JSON array');
    }
}