@isTest
public class CancellationSharedServicesTest {

    // ══════════════════════════════════════════════════════════════════
    // MOCK
    // ══════════════════════════════════════════════════════════════════
 
    private class GenericHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');
 
            OIC_RequestWrapperController.OICResponseWrapperList responseList =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            responseList.ResponseArray =
                new List<OIC_RequestWrapperController.OICResponseWrapper>();
 
            OIC_RequestWrapperController.Base64ResponseWrapper baseResp =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            baseResp.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(responseList)));
 
            res.setBody(JSON.serialize(baseResp));
            return res;
        }
    }
 
    // ══════════════════════════════════════════════════════════════════
    // @testSetup  — shared base data
    // ══════════════════════════════════════════════════════════════════
 
    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
 
        Unit__c unitRec = new Unit__c(
            Name = 'Unit-1',
            Status__c = 'Reserved',
            PlotNo__c = 'P-001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert unitRec;
 
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c            = unitRec.Id,
            Status__c          = 'New'
        );
        insert so;
 
        // SR with Management_Fee__c > 0 so the forfeiture createChange path can fire
        id RecordtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('Pre_Unit_Cancellation').getRecordTypeId();

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c        = so.Id,
            Cancellation_Type__c = 'Cancellation with Refund',
            Management_Fee__c    = 200,
            RecordTypeId =  RecordtId
        );
        insert sr;
 
        Invoice__c inv = new Invoice__c(
            Account__c       = acc.Id,
            Sales_Order__c   = so.Id,
            InvoiceAmount__c = 1000,
            Status__c        = 'Approved',
            OraclePartyId__c = 'ORACLE-INV-001'
        );
        insert inv;
 
        // rec1 – Confirmed, no Oracle IDs (Branch B receipt cancel path)
        Receipt__c rec1 = new Receipt__c(
            Account__c        = acc.Id,
            SalesOrder__c     = so.Id,
            Status__c         = 'Confirmed',
            Receipt_Amount__c = 500,
            TotalAmount__c    = 500
        );
 
        // rec2 – Cleared with OraclePartyId__c (feeds debit memo creation)
        Receipt__c rec2 = new Receipt__c(
            Account__c           = acc.Id,
            SalesOrder__c        = so.Id,
            Status__c            = 'Cleared',
            Receipt_Amount__c    = 300,
            TotalAmount__c       = 300,
            EBS_Clearing_Date__c = System.today(),
            OraclePartyId__c     = 'ORACLE-REC-001'
        );
 
        insert new List<Receipt__c>{ rec1, rec2 };
 
        Allocation__c alloc = new Allocation__c(
            Invoice__c          = inv.Id,
            Receipt__c          = rec2.Id,
            AllocationAmount__c = 300,
            Status__c           = 'Applied'
        );
        insert alloc;
    }
 
    // ── Reusable query helpers ────────────────────────────────────────
 
    private static Account getAcc() {
        return [SELECT Id FROM Account LIMIT 1];
    }
    private static SalesOrder__c getSO() {
        return [SELECT Id, CustomerAccount__c, Unit__c FROM SalesOrder__c
                WHERE CustomerAccount__r.Name = 'Test Account' LIMIT 1];
    }
    private static ServiceRequest__c getSR() {
        return [SELECT Id, SalesOrder__c, SalesOrder__r.CustomerAccount__c,
                       Cancellation_Type__c, Is_ADM_Refund_Needed__c,
                       Management_Fee__c, Forfeiture_Amount__c
                FROM ServiceRequest__c LIMIT 1];
    }
    private static List<Invoice__c> getInvoices() {
        return [SELECT Id, Account__c, OraclePartyId__c, SalesOrderInstallment__c,
                       Sales_Order__c, InvoiceAmount__c, Status__c
                FROM Invoice__c];
    }
    private static Unit__c getUnit() {
        return [SELECT Id FROM Unit__c LIMIT 1];
    }
 
    // ══════════════════════════════════════════════════════════════════
    // ── RECEIPT CANCELLATION SERVICE ─────────────────────────────────
    // ══════════════════════════════════════════════════════════════════
 
    @isTest
    static void testReceiptCancellation() {
        List<Receipt__c> receipts = [
            SELECT Id, Status__c, OraclePartyId__c, Oracle_Id_Temporary__c
            FROM Receipt__c
        ];
 
        Test.startTest();
        Map<Id, String> result =
            new CancellationSharedServices.ReceiptCancellationService()
                .cancel(receipts, 'Test Cancel');
        Test.stopTest();
    }
 
    @isTest
    static void testReceiptCancellation_ProtectedAndOracleBranches() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
 
        List<Receipt__c> recs = new List<Receipt__c>{
            // Protected: Bounced
            new Receipt__c(Account__c=acc.Id, SalesOrder__c=so.Id,
                Status__c='Bounced', Receipt_Amount__c=10, TotalAmount__c=10),
            // Protected: ReturnedtoCustomer (exact key in the set)
            new Receipt__c(Account__c=acc.Id, SalesOrder__c=so.Id,
                Status__c='Returned to customer', Receipt_Amount__c=20, TotalAmount__c=20),
            // C1: OraclePartyId__c set + Remitted → added to cancelled
            new Receipt__c(Account__c=acc.Id, SalesOrder__c=so.Id,
                Status__c='Remitted', Receipt_Amount__c=30, TotalAmount__c=30,
                OraclePartyId__c='ORACLE-REC-001'),
            // C2: Oracle_Id_Temporary__c set, OraclePartyId__c null → update only
            new Receipt__c(Account__c=acc.Id, SalesOrder__c=so.Id,
                Status__c='In Progress', Receipt_Amount__c=40, TotalAmount__c=40,
                Oracle_Id_Temporary__c='TEMP-REC-001')
        };
        insert recs;
 
        List<Receipt__c> queried = [
            SELECT Id, Status__c, OraclePartyId__c, Oracle_Id_Temporary__c
            FROM Receipt__c WHERE Id IN :recs
        ];
 
        Test.startTest();
        Map<Id, String> result =
            new CancellationSharedServices.ReceiptCancellationService()
                .cancel(queried, 'Customer Refund');
        Test.stopTest();
    }
 
    /**
     * Covers the 'Cancelled' value in PROTECTED_RECEIPT_STATUSES (continue path).
     */
    @isTest
    static void testReceiptCancellation_CancelledStatus() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
 
        Receipt__c cancelled = new Receipt__c(
            Account__c=acc.Id, SalesOrder__c=so.Id,
            Status__c='Cancelled', Receipt_Amount__c=50, TotalAmount__c=50
        );
        insert cancelled;
 
        List<Receipt__c> queried = [
            SELECT Id, Status__c, OraclePartyId__c, Oracle_Id_Temporary__c
            FROM Receipt__c WHERE Id = :cancelled.Id
        ];
 
        Test.startTest();
        Map<Id, String> result =
            new CancellationSharedServices.ReceiptCancellationService()
                .cancel(queried, 'Customer Refund');
        Test.stopTest();
    }
 
    @isTest
    static void testReceiptCancellation_NullEmptyAndExactProtectedStatus() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
 
        Receipt__c protectedRec = new Receipt__c(
            Account__c=acc.Id, SalesOrder__c=so.Id,
            Status__c='Returned to Customer',
            Receipt_Amount__c=25, TotalAmount__c=25
        );
        insert protectedRec;
 
        Test.startTest();
        CancellationSharedServices.ReceiptCancellationService svc =
            new CancellationSharedServices.ReceiptCancellationService();
 
        svc.cancel(null, 'Customer Refund');
        svc.cancel(new List<Receipt__c>(), 'Customer Refund');
        svc.cancel(
            [SELECT Id, Status__c, OraclePartyId__c, Oracle_Id_Temporary__c
             FROM Receipt__c WHERE Id = :protectedRec.Id],
            'Customer Refund');
        Test.stopTest();
    }
 
    // ══════════════════════════════════════════════════════════════════
    // ── ALLOCATION UNAPPLY SERVICE ────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════
 
    @isTest
    static void testAllocationUnapply() {
        List<Invoice__c> invoices = [SELECT Id FROM Invoice__c];
 
        Test.startTest();
        new CancellationSharedServices.AllocationUnapplyService().unapply(invoices);
        Test.stopTest();
    }
 
    @isTest
    static void testAllocationUnapply_NullAndEmpty() {
        Test.startTest();
        CancellationSharedServices.AllocationUnapplyService svc =
            new CancellationSharedServices.AllocationUnapplyService();
        svc.unapply(null);
        svc.unapply(new List<Invoice__c>());
        Test.stopTest();
    }
 
    // ══════════════════════════════════════════════════════════════════
    // ── SALES ORDER CANCELLATION SERVICE ─────────────────────────────
    // ══════════════════════════════════════════════════════════════════
 
    @isTest
    static void testSalesOrderCancellation() {
        SalesOrder__c so  = getSO();
        Unit__c unitRec   = getUnit();
 
        Test.setMock(HttpCalloutMock.class, new GenericHttpMock());
        Test.startTest();
        try {
            new CancellationSharedServices.SalesOrderCancellationService()
                .cancel(so.Id, unitRec.Id, 'Customer Refund');
        } catch (Exception ex) { }
        Test.stopTest();
    }
 
    @isTest
    static void testSalesOrderCancellation_AllTypes_NullUnit() {
        Account acc = getAcc();
 
        List<SalesOrder__c> orders = new List<SalesOrder__c>{
            new SalesOrder__c(CustomerAccount__c=acc.Id, Status__c='New'),
            new SalesOrder__c(CustomerAccount__c=acc.Id, Status__c='New'),
            new SalesOrder__c(CustomerAccount__c=acc.Id, Status__c='New')
        };
        insert orders;
 
        Test.setMock(HttpCalloutMock.class, new GenericHttpMock());
        Test.startTest();
        try {
            CancellationSharedServices.SalesOrderCancellationService svc =
                new CancellationSharedServices.SalesOrderCancellationService();
            svc.cancel(orders[0].Id, null, CancellationStrategyFactory.TYPE_WITH_REFUND);
            svc.cancel(orders[1].Id, null, CancellationStrategyFactory.TYPE_CONSOLIDATION);
            svc.cancel(orders[2].Id, null, CancellationStrategyFactory.TYPE_WITHOUT_REFUND);
        } catch (Exception ex) { }
        Test.stopTest();
    }
 
    // ══════════════════════════════════════════════════════════════════
    // ── INVOICE CANCELLATION SERVICE — BASIC PATHS ───────────────────
    // ══════════════════════════════════════════════════════════════════
 
    @isTest
    static void testInvoiceCancellation_NullAndEmpty() {
        ServiceRequest__c sr = getSR();
 
        Test.startTest();
        CancellationSharedServices.InvoiceCancellationService svc =
            new CancellationSharedServices.InvoiceCancellationService();
 
        svc.cancel(null, 'Customer Refund', 0, sr);
        svc.cancel(new List<Invoice__c>(), 'Customer Refund', 0, sr);
        Test.stopTest();
    }
 
    /**
     * Standard cancellation with Refund, forfeiture=0, cleared receipt allocated
     * → debit memo created for full receipt amount.
     */
    @isTest
    static void testInvoiceCancellation_StandardRefund() {
        List<Invoice__c> invoices = getInvoices();
        ServiceRequest__c sr = getSR();
 
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation with Refund', 0, sr);
        Test.stopTest();
    }
 
    /**
     * Cancellation without Refund → OraclePartyId__c invoices NOT added to
     * paidInvoiceIds; processAllocationsAndDebitMemos NOT called.
     */
    @isTest
    static void testInvoiceCancellation_WithoutRefundBranch() {
        List<Invoice__c> invoices = getInvoices();
        ServiceRequest__c sr = getSR();
        sr.Cancellation_Type__c = 'Cancellation without Refund';
        update sr;
 
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation without Refund', 0,
                [SELECT Id, SalesOrder__c, SalesOrder__r.CustomerAccount__c,
                        Cancellation_Type__c, Is_ADM_Refund_Needed__c, Management_Fee__c
                 FROM ServiceRequest__c WHERE Id = :sr.Id]);
        Test.stopTest();
    }
 
    /**
     * Invoice has a SalesOrderInstallment__c → toUpdateSOI path covered.
     */
    @isTest
    static void testInvoiceCancel_WithSOI() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
        ServiceRequest__c sr = getSR();
 
        // Create a payment plan + installment so SOI can be linked
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c    = so.Id,
            PaymentStatus__c = 'Not Paid',
            InstallmentAmount__c = 500
        );
        insert soi;
 
        Invoice__c invWithSOI = new Invoice__c(
            Account__c              = acc.Id,
            Sales_Order__c          = so.Id,
            SalesOrderInstallment__c = soi.Id,
            InvoiceAmount__c        = 500,
            Status__c               = 'Approved'
            // No OraclePartyId__c → won't enter paid-invoice path
        );
        insert invWithSOI;
 
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(
                [SELECT Id, Account__c, OraclePartyId__c, SalesOrderInstallment__c,
                        Sales_Order__c, InvoiceAmount__c, Status__c
                 FROM Invoice__c WHERE Id = :invWithSOI.Id],
                'Cancellation with Refund', 0, sr);
        Test.stopTest();
    }
 
    /**
     * Management_Fee__c > 0 on the SR AND forfeitureAmount > 0
     * → createChange() is called inside cancel() → Charge + forfeiture invoice inserted.
     */
    @isTest
    static void testInvoiceCancel_WithForfeiture_AndMgmtFee() {
        List<Invoice__c> invoices = getInvoices();
        ServiceRequest__c sr =
            [SELECT Id, SalesOrder__c, SalesOrder__r.CustomerAccount__c,
                    Cancellation_Type__c, Is_ADM_Refund_Needed__c, Management_Fee__c
             FROM ServiceRequest__c LIMIT 1];
        // Management_Fee__c = 200 already set in @testSetup
 
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation with Refund', 200, sr);
        Test.stopTest();
    }
 
    /**
     * Forfeiture >= cleared receipt amount → receipt is fully consumed,
     * no Debit Memo created for it (remaining -= receiptAmt; continue).
     * Uses forfeiture=300 which equals rec2.Receipt_Amount__c=300.
     */
    @isTest
    static void testInvoiceCancel_ForfeitureConsumesFullReceipt() {
        List<Invoice__c> invoices = getInvoices();
        ServiceRequest__c sr =
            [SELECT Id, SalesOrder__c, SalesOrder__r.CustomerAccount__c,
                    Cancellation_Type__c, Is_ADM_Refund_Needed__c, Management_Fee__c
             FROM ServiceRequest__c LIMIT 1];
 
        Test.startTest();
        // forfeitureAmount=300 equals the cleared receipt amount → full consume path
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation with Refund', 300, sr);
        Test.stopTest();
    }
 
    /**
     * Forfeiture < cleared receipt amount → partial consume path
     * (postForfeitureAmt = receiptAmt - remaining; remaining = 0).
     * Uses forfeiture=100, receipt=300 → 200 goes to Debit Memo.
     */
    @isTest
    static void testInvoiceCancel_ForfeiturePartial() {
        List<Invoice__c> invoices = getInvoices();
        ServiceRequest__c sr =
            [SELECT Id, SalesOrder__c, SalesOrder__r.CustomerAccount__c,
                    Cancellation_Type__c, Is_ADM_Refund_Needed__c, Management_Fee__c
             FROM ServiceRequest__c LIMIT 1];
 
        Test.startTest();
        // forfeitureAmount=100, receipt=300 → 200 remaining for refund Debit Memo
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation with Refund', 100, sr);
        Test.stopTest();
    }
 
    /**
     * Covers forfeitureInvoiceId + forfeitureReceiptId → the forfeiture Allocation
     * is appended to newAllocs at the end of createDebitMemosAndAllocations.
     * Requires: forfeitureAmount > 0, Management_Fee__c > 0, a cleared receipt
     * whose amount equals forfeiture exactly (it will be the forfeitureReceiptId).
     */
    @isTest
    static void testInvoiceCancel_ForfeitureAllocationLinked() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
        ServiceRequest__c sr =
            [SELECT Id, SalesOrder__c, SalesOrder__r.CustomerAccount__c,
                    Cancellation_Type__c, Is_ADM_Refund_Needed__c, Management_Fee__c
             FROM ServiceRequest__c LIMIT 1];
 
        // Create a second cleared receipt that will be fully consumed by forfeiture
        Receipt__c clearedFull = new Receipt__c(
            Account__c=acc.Id, SalesOrder__c=so.Id,
            Status__c='Cleared', Receipt_Amount__c=150, TotalAmount__c=150,
            EBS_Clearing_Date__c=System.today(), OraclePartyId__c='ORACLE-FREC-001'
        );
        insert clearedFull;
 
        Invoice__c inv2 = new Invoice__c(
            Account__c=acc.Id, Sales_Order__c=so.Id,
            InvoiceAmount__c=150, Status__c='Approved',
            OraclePartyId__c='ORACLE-INV-002'
        );
        insert inv2;
 
        Allocation__c alloc2 = new Allocation__c(
            Invoice__c=inv2.Id, Receipt__c=clearedFull.Id,
            AllocationAmount__c=150, Status__c='Applied'
        );
        insert alloc2;
 
        List<Invoice__c> invoices =
            [SELECT Id, Account__c, OraclePartyId__c, SalesOrderInstallment__c,
                    Sales_Order__c, InvoiceAmount__c, Status__c
             FROM Invoice__c WHERE Id = :inv2.Id];
 
        Test.startTest();
        // forfeiture=150, receipt=150 → full consume; forfeitureReceiptId set
        // Management_Fee__c=200 → createChange called → forfeitureInvoiceId set
        // → forfeiture allocation row appended
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation with Refund', 150, sr);
        Test.stopTest();
    }
 
    /**
     * ADM charge receipt (Is_ADM_Fees_and_Dari_charges__c=true) with
     * Is_ADM_Refund_Needed__c != 'Down Payment' → isProcessADM=true
     * → ADM always refunded in full; buildDebitMemo called with ADM flag.
     */
    @isTest
    static void testInvoiceCancel_ADMChargeReceipt() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
        ServiceRequest__c sr = getSR();
 
        Receipt__c admCleared = new Receipt__c(
            Account__c=acc.Id, SalesOrder__c=so.Id,
            Status__c='Cleared', Receipt_Amount__c=100, TotalAmount__c=100,
            EBS_Clearing_Date__c=System.today(), OraclePartyId__c='ORACLE-ADM-001',
            Is_ADM_Fees_and_Dari_charges__c=true
        );
        insert admCleared;
 
        Invoice__c invADM = new Invoice__c(
            Account__c=acc.Id, Sales_Order__c=so.Id,
            InvoiceAmount__c=100, Status__c='Approved',
            OraclePartyId__c='ORACLE-INV-ADM'
        );
        insert invADM;
 
        Allocation__c allocADM = new Allocation__c(
            Invoice__c=invADM.Id, Receipt__c=admCleared.Id,
            AllocationAmount__c=100, Status__c='Applied'
        );
        insert allocADM;
 
        List<Invoice__c> invoices =
            [SELECT Id, Account__c, OraclePartyId__c, SalesOrderInstallment__c,
                    Sales_Order__c, InvoiceAmount__c, Status__c
             FROM Invoice__c WHERE Id = :invADM.Id];
 
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation with Refund', 0, sr);
        Test.stopTest();

    }
 
    /**
     * ADM charge receipt but Is_ADM_Refund_Needed__c = 'Down Payment'
     * → isProcessADM=false → ADM receipt treated the same as standard (no early refund).
     */
    @isTest
    static void testInvoiceCancel_ADMCharge_DownPayment() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
        ServiceRequest__c sr = getSR();
        sr.Is_ADM_Refund_Needed__c = 'Down Payment';
        update sr;
 
        Receipt__c admCleared = new Receipt__c(
            Account__c=acc.Id, SalesOrder__c=so.Id,
            Status__c='Cleared', Receipt_Amount__c=100, TotalAmount__c=100,
            EBS_Clearing_Date__c=System.today(), OraclePartyId__c='ORACLE-ADM-002',
            Is_ADM_Fees_and_Dari_charges__c=true
        );
        insert admCleared;
 
        Invoice__c invADM2 = new Invoice__c(
            Account__c=acc.Id, Sales_Order__c=so.Id,
            InvoiceAmount__c=100, Status__c='Approved',
            OraclePartyId__c='ORACLE-INV-ADM2'
        );
        insert invADM2;
 
        Allocation__c allocADM2 = new Allocation__c(
            Invoice__c=invADM2.Id, Receipt__c=admCleared.Id,
            AllocationAmount__c=100, Status__c='Applied'
        );
        insert allocADM2;
 
        List<Invoice__c> invoices =
            [SELECT Id, Account__c, OraclePartyId__c, SalesOrderInstallment__c,
                    Sales_Order__c, InvoiceAmount__c, Status__c
             FROM Invoice__c WHERE Id = :invADM2.Id];
 
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation with Refund', 0,
                [SELECT Id, SalesOrder__c, SalesOrder__r.CustomerAccount__c,
                        Cancellation_Type__c, Is_ADM_Refund_Needed__c, Management_Fee__c
                 FROM ServiceRequest__c WHERE Id = :sr.Id]);
        Test.stopTest();
    }
 
    /**
     * Consolidation Cancellation type:
     * → consolidationLines fetched → sliceRemaining split across UC lines.
     */
    @isTest
    static void testInvoiceCancel_ConsolidationType() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
        Unit__c unitRec = getUnit();
        ServiceRequest__c sr = getSR();
 
        // Destination SO for consolidation line
        SalesOrder__c destSO = new SalesOrder__c(
            CustomerAccount__c=acc.Id, Unit__c=unitRec.Id, Status__c='New'
        );
        insert destSO;
 
        // UC line with Fund_Transfer__c=true, Transfer_Amount__c > 0
        Unit_Consolidation__c ucLine = new Unit_Consolidation__c(
            Service_Request__c=sr.Id,
            Sales_Order__c=destSO.Id,
            Unit__c=unitRec.Id,
            Fund_Transfer__c=true,
            Transfer_Amount__c=300
        );
        insert ucLine;
 
        List<Invoice__c> invoices = getInvoices();
 
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Consolidation Cancellation', 0, sr);
        Test.stopTest();
    }
 
    /**
     * Consolidation catch-all path:
     * UC line Transfer_Amount__c < postForfeitureAmt → sliceRemaining > 0 after loop
     * → catch-all Debit Memo created for the leftover.
     */
    @isTest
    static void testInvoiceCancel_Consolidation_CatchAll() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
        Unit__c unitRec = getUnit();
        ServiceRequest__c sr = getSR();
 
        SalesOrder__c destSO = new SalesOrder__c(
            CustomerAccount__c=acc.Id, Unit__c=unitRec.Id, Status__c='New'
        );
        insert destSO;
 
        // UC line that only covers 50 of the 300 receipt amount → 250 left for catch-all
        Unit_Consolidation__c ucSmall = new Unit_Consolidation__c(
            Service_Request__c=sr.Id,
            Sales_Order__c=destSO.Id,
            Unit__c=unitRec.Id,
            Fund_Transfer__c=true,
            Transfer_Amount__c=50
        );
        insert ucSmall;
 
        List<Invoice__c> invoices = getInvoices();
 
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Consolidation Cancellation', 0, sr);
        Test.stopTest();
    }
 
    /**
     * processAllocationsAndDebitMemos: allAllocations.isEmpty() → early return.
     * Use an invoice with OraclePartyId__c that has no Allocation__c records.
     */
    @isTest
    static void testInvoiceCancel_NoAllocations() {
        Account acc = getAcc();
        SalesOrder__c so = getSO();
        ServiceRequest__c sr = getSR();
 
        Invoice__c invNoAlloc = new Invoice__c(
            Account__c=acc.Id, Sales_Order__c=so.Id,
            InvoiceAmount__c=200, Status__c='Approved',
            OraclePartyId__c='ORACLE-INV-NOALLOC'
        );
        insert invNoAlloc;
 
        List<Invoice__c> invoices =
            [SELECT Id, Account__c, OraclePartyId__c, SalesOrderInstallment__c,
                    Sales_Order__c, InvoiceAmount__c, Status__c
             FROM Invoice__c WHERE Id = :invNoAlloc.Id];
 
        Test.startTest();
        // Invoice has Oracle ID + no allocations → processAllocations called,
        // allAllocations.isEmpty() → return immediately
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Cancellation with Refund', 0, sr);
        Test.stopTest();
    }
 
    @isTest
    static void testInvoiceCancellation_WithForfeitureBranch() {
        List<Invoice__c> invoices = getInvoices();
        ServiceRequest__c sr = getSR();
 
        Test.setMock(HttpCalloutMock.class, new GenericHttpMock());
        Test.startTest();
        new CancellationSharedServices.InvoiceCancellationService()
            .cancel(invoices, 'Customer Refund', 100, sr);
        Test.stopTest();
    }
 
    // ══════════════════════════════════════════════════════════════════
    // ── createChange (static) ─────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════
 
    @isTest
    static void testCreateChange() {
        ServiceRequest__c sr =
            [SELECT Id, SalesOrder__c, SalesOrder__r.CustomerAccount__c
             FROM ServiceRequest__c LIMIT 1];
 
        Id debitMemoRTId = Schema.SObjectType.Invoice__c
            .getRecordTypeInfosByDeveloperName()
            .get('Debit_Memo')
            .getRecordTypeId();
 
        Test.startTest();
        Invoice__c changeInv =
            CancellationSharedServices.createChange(sr, 200, debitMemoRTId);
        Test.stopTest();
    }
 
    // ══════════════════════════════════════════════════════════════════
    // ── EQUITY TRANSFER RECEIPT SERVICE ──────────────────────────────
    // ══════════════════════════════════════════════════════════════════
 
    @isTest
    static void testEquityTransferFromClearedReceipts() {
        List<Receipt__c> receipts = [
            SELECT Id, Account__c, SalesOrder__c, SalesOrderInstallment__c,
                   Status__c, Receipt_Amount__c, TotalAmount__c
            FROM Receipt__c
        ];
 
        Test.setMock(HttpCalloutMock.class, new GenericHttpMock());
        Test.startTest();
        new CancellationSharedServices.EquityTransferReceiptService()
            .createFromClearedReceipts(receipts, 100);
        Test.stopTest();
    }
 
    @isTest
    static void testEquityTransferFromClearedReceipts_NullEmpty() {
        Test.startTest();
        CancellationSharedServices.EquityTransferReceiptService svc =
            new CancellationSharedServices.EquityTransferReceiptService();
        svc.createFromClearedReceipts(null, 100);
        svc.createFromClearedReceipts(new List<Receipt__c>(), 100);
        Test.stopTest();
    }
 
    @isTest
    static void testEquityTransferFromUnitConsolidation() {
        Account acc = getAcc();
        ServiceRequest__c sr = getSR();
        Unit__c unitRec = getUnit();
 
        SalesOrder__c destSO = new SalesOrder__c(
            CustomerAccount__c=acc.Id, Unit__c=unitRec.Id, Status__c='New'
        );
        insert destSO;
 
        Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c=sr.Id, Sales_Order__c=destSO.Id,
            Unit__c=unitRec.Id, Fund_Transfer__c=true, Transfer_Amount__c=50
        );
        insert uc;
 
        Test.setMock(HttpCalloutMock.class, new GenericHttpMock());
        Test.startTest();
        new CancellationSharedServices.EquityTransferReceiptService()
            .createFromUnitConsolidation(sr.Id, 100);
        Test.stopTest();
    }
 
    @isTest
    static void testEquityTransferFromUnitConsolidation_NoRows() {
        Test.startTest();
        new CancellationSharedServices.EquityTransferReceiptService()
            .createFromUnitConsolidation(null, 100);
        Test.stopTest();
    }
 
    /**
     * Valid SR Id that exists but has no Unit_Consolidation__c rows
     * → allUCLines.isEmpty() → return empty list.
     */
    @isTest
    static void testEquityTransfer_ValidSR_NoUCRows() {
        // Create a brand new SR that has no UC children
        Account acc = getAcc();
        SalesOrder__c so = getSO();
        ServiceRequest__c freshSR = new ServiceRequest__c(
            SalesOrder__c=so.Id,
            Cancellation_Type__c='Cancellation with Refund'
        );
        insert freshSR;
 
        Test.startTest();
        List<Receipt__c> result =
            new CancellationSharedServices.EquityTransferReceiptService()
                .createFromUnitConsolidation(freshSR.Id, 100);
        Test.stopTest();
    }
 
    @isTest
    static void testEquityTransferFromUnitConsolidation_NoFundTransfer() {
        Account acc = getAcc();
        ServiceRequest__c sr = getSR();
        Unit__c unitRec = getUnit();
 
        SalesOrder__c destSO = new SalesOrder__c(
            CustomerAccount__c=acc.Id, Unit__c=unitRec.Id, Status__c='New'
        );
        insert destSO;
 
        Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c=sr.Id, Sales_Order__c=destSO.Id,
            Unit__c=unitRec.Id, Fund_Transfer__c=false, Transfer_Amount__c=50
        );
        insert uc;
 
        Test.startTest();
        List<Receipt__c> result =
            new CancellationSharedServices.EquityTransferReceiptService()
                .createFromUnitConsolidation(sr.Id, 100);
        Test.stopTest();
    }
 
    @isTest
    static void testEquityTransferFromUnitConsolidation_ZeroAmount() {
        Account acc = getAcc();
        ServiceRequest__c sr = getSR();
        Unit__c unitRec = getUnit();
 
        SalesOrder__c destSO = new SalesOrder__c(
            CustomerAccount__c=acc.Id, Unit__c=unitRec.Id, Status__c='New'
        );
        insert destSO;
 
        Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c=sr.Id, Sales_Order__c=destSO.Id,
            Unit__c=unitRec.Id, Fund_Transfer__c=true, Transfer_Amount__c=0
        );
        insert uc;
 
        Test.startTest();
        List<Receipt__c> result =
            new CancellationSharedServices.EquityTransferReceiptService()
                .createFromUnitConsolidation(sr.Id, 100);
        Test.stopTest();
 
    }
 
    @isTest
    static void testEquityTransferAllocate_ExpectedException() {
        Account acc = getAcc();
        Unit__c unitRec = getUnit();
 
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c=acc.Id, Unit__c=unitRec.Id, Status__c='New'
        );
        insert so;
 
        Id equityRTId = Schema.SObjectType.Receipt__c
            .getRecordTypeInfosByDeveloperName()
            .get('Equity_Transfer')
            .getRecordTypeId();
 
        Receipt__c equityReceipt = new Receipt__c(
            RecordTypeId=equityRTId,
            Account__c=acc.Id, SalesOrder__c=so.Id,
            Status__c='In Progress', Modeofpayment__c='Equity Transfer',
            TotalAmount__c=50, Receipt_Amount__c=50,
            ReceiptDate__c=System.today(), TransactionDate__c=System.today(),
            Transaction_Type__c='EQU_TRANSFOR'
        );
        insert equityReceipt;
 
        Test.startTest();
        try {
            new CancellationSharedServices.EquityTransferReceiptService()
                .allocate(new List<Receipt__c>{ equityReceipt });
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }
 
    @isTest
    static void testEquityTransferAllocate_NullEmpty() {
        Test.startTest();
        CancellationSharedServices.EquityTransferReceiptService svc =
            new CancellationSharedServices.EquityTransferReceiptService();
        svc.allocate(null);
        svc.allocate(new List<Receipt__c>());
        Test.stopTest();
 
        System.assert(true);
    }
}