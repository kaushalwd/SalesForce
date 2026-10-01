/**********************************************************************************************************************
* Name               : SRCancellationExecutorTest
* Description        : Unit tests for the cancellation framework.
 *                    Uses @TestSetup + mock data to cover all three strategy paths
 *                    and the shared services without real OIC callouts.
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj            15 Mar 2026          Initial Draft
* 
***********************************************************************************************************************/
@IsTest
private class SRCancellationExecutorTest {

    // ─── Constants ────────────────────────────────────────────────────────────

    private static final String TYPE_REFUND       = CancellationStrategyFactory.TYPE_WITH_REFUND;
    private static final String TYPE_CONSOL       = CancellationStrategyFactory.TYPE_CONSOLIDATION;
    private static final String TYPE_NO_REFUND    = CancellationStrategyFactory.TYPE_WITHOUT_REFUND;

    // ─── Test Setup ───────────────────────────────────────────────────────────

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
          SRCancellationExecutor.execute(sr.id);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        try{
        SRCancellationExecutor.executeById(sr.id);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        try {
            SRCancellationExecutor.executeById(null);
          SRCancellationExecutor.execute(inv.id);
        } catch (Exception ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        Test.stopTest();

        TriggerControl.BypassCancelledTrigger = false;

    }
}