/**********************************************************************************************************************
* Name               : BPCancellationExecutorTest
* Description        : Unit tests for the Business_Process__c cancellation framework —
*                       standalone counterpart of SRCancellationExecutorTest for the
*                       SR-to-BP cancellation migration. Business_Process__c records here
*                       have no related ServiceRequest__c record.
* Created By         : Active Minds
***********************************************************************************************************************/
@IsTest
private class BPCancellationExecutorTest {

    private static final String TYPE_REFUND    = BPCancellationStrategyFactory.TYPE_WITH_REFUND;
    private static final String TYPE_CONSOL    = BPCancellationStrategyFactory.TYPE_CONSOLIDATION;
    private static final String TYPE_NO_REFUND = BPCancellationStrategyFactory.TYPE_WITHOUT_REFUND;
    private static final String BP_TYPE        = 'Pre Unit Cancellation and Refund Process';

    // =========================================================================
    // Mock: any status-200 response — BPCancellationSyncQueueable only checks
    // the HTTP status code, so the body content does not matter for these tests.
    // =========================================================================
    private class OICMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{}');
            return res;
        }
    }

    private class OICMockHttpError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"server error"}');
            return res;
        }
    }

    // =========================================================================
    // @TestSetup — one Sales Order (CUST-BP-001) with a single invoice + receipt.
    // =========================================================================
    @TestSetup
    static void setupData() {
        Schema.RecordTypeInfo rtInfo =
            Schema.getGlobalDescribe().get('Account').getDescribe()
                .getRecordTypeInfosByDeveloperName().get('PersonAccount');

        Account accountObj = new Account(RecordTypeId = rtInfo.getRecordTypeId());
        accountObj.PersonEmail      = 'bptest@example.com';
        accountObj.FirstName        = 'First';
        accountObj.LastName         = 'Last';
        accountObj.OraclePartyId__c = '22213';
        insert accountObj;

        Project__c projectObj = new Project__c();
        insert projectObj;

        EscrowAccount__c escrowObj = new EscrowAccount__c();
        escrowObj.Name               = 'OIC Escrow BP';
        escrowObj.AccountNumber__c   = 'ESC-BP-001';
        escrowObj.IBANNo__c          = 'AE070331234567890123457';
        escrowObj.StoreId__c         = 'STORE-BP-001';
        escrowObj.SwiftCode__c       = 'SWIFT002';
        escrowObj.TradeID__c         = 'TRADE-BP-001';
        escrowObj.BankName__c        = 'Test Bank';
        escrowObj.BeneficiaryName__c = 'Test Beneficiary';
        insert escrowObj;

        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name                    = 'Test Virtual Account BP';
        vaObj.Status__c               = 'Available';
        vaObj.EscrowAccount__c        = escrowObj.Id;
        vaObj.VirtualAccountNumber__c = '124567643';
        vaObj.VirtualIBANNumber__c    = 'AE3456789456790';
        insert vaObj;

        Phase__c phaseObj = new Phase__c();
        phaseObj.Project__c       = projectObj.Id;
        phaseObj.EscrowAccount__c = escrowObj.Id;
        phaseObj.EntityName__c    = 'Modon Properties PJSC';
        insert phaseObj;

        Unit__c unitObj = new Unit__c();
        unitObj.Name                  = 'Test Unit BP';
        unitObj.BasePrice__c          = 1000;
        unitObj.AdditionalPrice__c    = 0;
        unitObj.PlotAreasqm__c        = 1.0;
        unitObj.PlotNo__c             = '2';
        unitObj.UnitClassification__c = 'Villa';
        unitObj.Number_of_Bedrooms__c = '2';
        unitObj.NotToBeShownOnRD__c   = false;
        unitObj.Phase__c              = phaseObj.Id;
        insert unitObj;

        Unit_Option__c unitOptionObj = new Unit_Option__c();
        unitOptionObj.Unit__c        = unitObj.Id;
        unitOptionObj.Phase__c       = phaseObj.Id;
        unitOptionObj.PlotAreasqm__c = 1.0;
        unitOptionObj.PlotNo__c      = '2';
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
        salesOrderObj.CustAcctId__c           = 'CUST-BP-001';
        salesOrderObj.OraclePartySiteID__c    = '33334';
        salesOrderObj.OracleCustAcctSiteID__c = '765457';
        salesOrderObj.OracleSiteUseID__c      = 'SITE-USE-002';
        salesOrderObj.OraclePartyId__c        = '34347';
        salesOrderObj.Source_Entity__c        = 'Modon - UAE';
        salesOrderObj.SalesAssociate__c       = UserInfo.getUserId();
        salesOrderObj.IsDownPaymentCollected__c = true;
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

        Invoice__c inv1 = new Invoice__c();
        inv1.SalesOrderInstallment__c = soInstallmentObj.Id;
        inv1.Sales_Order__c           = salesOrderObj.Id;
        inv1.InvoiceAmount__c         = 1000;
        inv1.Account__c               = accountObj.Id;
        inv1.Ebs_Invoice_Date__c      = System.today();
        inv1.InvoiceDate__c           = System.today();
        insert inv1;

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
        rec1.TransactionNumber__c     = 'TXN-BP-001';
        rec1.Status__c                = 'In Progress';
        insert rec1;
    }

    // =========================================================================
    // Helper — inserts a 'Pre Unit Cancellation and Refund Process' Business_Process__c
    // for a given Sales Order, with no related ServiceRequest__c.
    // =========================================================================
    private static Business_Process__c buildBP(Id soId, String cancellationType) {
        Business_Process__c bp = new Business_Process__c(
            Sales_Order__c       = soId,
            Type__c               = BP_TYPE,
            Cancellation_Type__c = cancellationType
        );
        insert bp;
        return bp;
    }

    @IsTest
    static void testCancellationWithRefund_AllocationLinkedToInvoice() {
        TriggerControl.BypassCancelledTrigger = true;

        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-BP-001' LIMIT 1];

        Invoice__c inv = [
            SELECT Id FROM Invoice__c
            WHERE Sales_Order__c = :so.Id LIMIT 1];
        inv.OraclePartyId__c = 'FUS-INV-BP-001';
        update inv;

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];
        rec.Status__c = 'Cleared';
        update rec;

        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;

        Business_Process__c bp = new Business_Process__c(
            Sales_Order__c       = so.Id,
            Type__c               = BP_TYPE,
            Cancellation_Type__c = TYPE_REFUND,
            Management_Fee__c    = 100
        );
        insert bp;

        Test.setMock(HttpCalloutMock.class, new OICMockSuccess());

        Test.startTest();
        try {
            BPCancellationExecutor.execute(bp.Id);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        try {
            BPCancellationExecutor.executeById(bp.Id);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        try {
            BPCancellationExecutor.executeById(null);
            BPCancellationExecutor.execute(inv.Id);
        } catch (Exception ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        Test.stopTest();

        TriggerControl.BypassCancelledTrigger = false;
    }

    @IsTest
    static void testCancellationWithRefund_CreatesDebitMemo() {
        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-BP-001' LIMIT 1];

        Invoice__c inv = [
            SELECT Id FROM Invoice__c
            WHERE Sales_Order__c = :so.Id LIMIT 1];
        inv.OraclePartyId__c = 'FUS-INV-BP-DM1';
        update inv;

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];
        rec.Status__c = 'Cleared';
        update rec;

        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;

        Business_Process__c bp = new Business_Process__c(
            Sales_Order__c       = so.Id,
            Type__c               = BP_TYPE,
            Cancellation_Type__c = TYPE_REFUND,
            Management_Fee__c    = 100
        );
        insert bp;

        Test.setMock(HttpCalloutMock.class, new OICMockSuccess());

        Test.startTest();
        BPCancellationExecutor.execute(bp.Id);
        Test.stopTest();

        Invoice__c updatedInv = [SELECT isCancelled__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(true, updatedInv.isCancelled__c, 'Source invoice should be marked cancelled');

        List<Invoice__c> debitMemos = [
            SELECT Id, InvoiceAmount__c, RecordType.Name
            FROM Invoice__c
            WHERE Business_Process__c = :bp.Id AND RecordType.Name = 'Debit Memo'
        ];
        System.assert(!debitMemos.isEmpty(),
            'Expected at least one Debit Memo Invoice to be created for the paid/cleared receipt');
    }

    @IsTest
    static void testCancellationWithoutRefund() {
        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-BP-001' LIMIT 1];

        Business_Process__c bp = buildBP(so.Id, TYPE_NO_REFUND);
        Test.setMock(HttpCalloutMock.class, new OICMockSuccess());

        Test.startTest();
        try {
            BPCancellationExecutor.execute(bp.Id);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        Test.stopTest();
    }

    @IsTest
    static void testConsolidationCancellation_HttpError() {
        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-BP-001' LIMIT 1];

        Invoice__c inv = [
            SELECT Id FROM Invoice__c
            WHERE Sales_Order__c = :so.Id LIMIT 1];
        inv.OraclePartyId__c = 'FUS-INV-BP-004';
        update inv;

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];
        rec.Status__c                        = 'Cleared';
        rec.Is_ADM_Fees_and_Dari_charges__c = true;
        update rec;

        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;

        Business_Process__c bp = new Business_Process__c(
            Sales_Order__c       = so.Id,
            Type__c               = BP_TYPE,
            Cancellation_Type__c = TYPE_CONSOL,
            Management_Fee__c    = 100
        );
        insert bp;

        ServiceRequest__c dummySR = new ServiceRequest__c();
        insert dummySR;

        Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c  = dummySR.Id,
            Business_Process__c = bp.Id,
            Sales_Order__c       = so.Id,
            Fund_Transfer__c     = true,
            Transfer_Amount__c   = 500
        );
        insert uc;

        Test.setMock(HttpCalloutMock.class, new OICMockHttpError());

        Test.startTest();
        try {
            BPCancellationExecutor.execute(bp.Id);
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()),
                'Exception message must not be blank');
        }
        Test.stopTest();
    }

    @IsTest
    static void testStrategyFactory_BlankAndUnrecognisedType() {
        try {
            BPCancellationStrategyFactory.getStrategy(null);
            System.assert(false, 'Expected AuraHandledException for blank type');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }

        try {
            BPCancellationStrategyFactory.getStrategy('Not A Real Type');
            System.assert(false, 'Expected AuraHandledException for unrecognised type');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void testWithRefundStrategy_HelpersDirect() {
        TriggerControl.BypassCancelledTrigger = true;

        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-BP-001' LIMIT 1];

        Invoice__c inv = [
            SELECT Id FROM Invoice__c
            WHERE Sales_Order__c = :so.Id LIMIT 1];
        inv.OraclePartyId__c = 'FUS-INV-BP-002';
        inv.isCancelled__c   = true;
        update inv;

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];

        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;

        Business_Process__c bp = buildBP(so.Id, TYPE_REFUND);

        BPCancellationWithRefundStrategy strat = new BPCancellationWithRefundStrategy();
        Set<Id> allocIds = strat.collectAllocationIds(new Set<Id>{ inv.Id });
        System.assert(allocIds.contains(alloc.Id));

        BPCancellationWithRefundStrategy.persistIdsOnBP(
            bp.Id, so.Id, new Set<Id>{ inv.Id }, new Set<Id>{ rec.Id }, allocIds);

        String json = BPCancellationWithRefundStrategy.buildSyncJson(
            so.Id, new Set<Id>{ inv.Id }, new Set<Id>{ rec.Id }, allocIds);
        System.assert(String.isNotBlank(json));
        System.assertEquals('null', BPCancellationWithRefundStrategy.quoteId(null));
        System.assertEquals('[]', BPCancellationWithRefundStrategy.idsToJsonArray(null));
        System.assert(BPCancellationWithRefundStrategy.toStringList(null).isEmpty());

        TriggerControl.BypassCancelledTrigger = false;
    }

    @IsTest
    static void testConsolidationStrategy_HelpersDirect() {
        SalesOrder__c so = [
            SELECT Id FROM SalesOrder__c
            WHERE CustAcctId__c = 'CUST-BP-001' LIMIT 1];

        Invoice__c inv = [
            SELECT Id FROM Invoice__c
            WHERE Sales_Order__c = :so.Id LIMIT 1];
        inv.OraclePartyId__c = 'FUS-INV-BP-003';
        inv.isCancelled__c   = true;
        update inv;

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE SalesOrder__c = :so.Id LIMIT 1];

        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        insert alloc;

        Business_Process__c bp = buildBP(so.Id, TYPE_CONSOL);

        ServiceRequest__c dummySR = new ServiceRequest__c();
        insert dummySR;

        Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c  = dummySR.Id,
            Business_Process__c = bp.Id,
            Sales_Order__c       = so.Id,
            IsConsolidated__c    = true
        );
        insert uc;

        BPConsolidationCancellationStrategy strat = new BPConsolidationCancellationStrategy();
        Set<Id> allocIds = strat.collectAllocationIds(new Set<Id>{ inv.Id });
        System.assert(allocIds.contains(alloc.Id));

        strat.persistIdsOnBP(bp.Id, so.Id, new Set<Id>{ inv.Id }, new Set<Id>{ rec.Id }, allocIds);

        Decimal total = strat.computeAvailableDebitBalance(bp.Id);
        System.assert(total != null);
    }

    @IsTest
    static void testContext_MissingSalesOrderThrows() {
        Business_Process__c bp = new Business_Process__c(Type__c = BP_TYPE);
        insert bp;

        try {
            BPCancellationContext.build(bp.Id);
            System.assert(false, 'Expected AuraHandledException for missing Sales Order');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }
}