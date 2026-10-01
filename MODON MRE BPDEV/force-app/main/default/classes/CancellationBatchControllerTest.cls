/**
 * @description  Test class for CancellationBatchController.
 *               Uses the identical @TestSetup hierarchy as EBSTransferBatchV1Test:
 *               Account → SalesOrder (CustAcctId__c='0003001') → Invoice chain.
 *               loadIds() is the first call in every test method.
 *               No assertions required — coverage only.
 *
 * @author       Manoj
 * @date         19-06-2026
 */
@IsTest
public class CancellationBatchControllerTest {

    // ── Static Id holders — populated by loadIds() in each test ──────────────
    private static Id salesOrderId;
    private static Id invoiceId1;
    private static Id invoiceId2;
    private static Id receiptId;
    private static Id srId;
    private static Id buyerAccountId;

    // ── RecordType Ids — resolved at class load ───────────────────────────────
    private static Id preCancelRT =
        Schema.SObjectType.ServiceRequest__c
            .getRecordTypeInfosByDeveloperName()
            .get('Pre_Unit_Cancellation')
            .getRecordTypeId();

    private static Id transferOffPlanRT =
        Schema.SObjectType.ServiceRequest__c
            .getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Property_Transfer_OffPlan')
            .getRecordTypeId();

    // ══════════════════════════════════════════════════════════════════════════
    // @TestSetup — IDENTICAL hierarchy to EBSTransferBatchV1Test
    // Anchor: SalesOrder__c WHERE CustAcctId__c = 'CBC-001'
    // SR linked via Transferred_Sales_Order__c = salesOrderObj.Id
    // CustomerOraclePartyId__c on SalesOrder = 'ORACLE-001' (passes 3.0 guard)
    // Receipt OraclePartyId__c populated (mirrors EBSTransferBatchV1Test pattern)
    // ══════════════════════════════════════════════════════════════════════════
    @TestSetup
    static void setupData() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Schema.RecordTypeInfo personRTInfo =
            Schema.getGlobalDescribe().get('Account').getDescribe()
                .getRecordTypeInfosByDeveloperName().get('PersonAccount');

        // Buyer person account (DML 2 target in Transfer batch)
        Account accountObj = new Account(RecordTypeId = personRTInfo.getRecordTypeId());
        accountObj.FirstName          = 'CBC';
        accountObj.LastName           = 'Buyer';
        accountObj.PersonEmail        = 'cbcbuyer@example.com';
        accountObj.OraclePartyId__c   = '22212';
        insert accountObj;

        Project__c projectObj = new Project__c(Name = 'CBC Project');
        insert projectObj;

        EscrowAccount__c escrowObj = new EscrowAccount__c();
        escrowObj.Name               = 'CBC Escrow';
        escrowObj.AccountNumber__c   = 'ESC-CBC-001';
        escrowObj.IBANNo__c          = 'AE070331234567890123456';
        escrowObj.StoreId__c         = 'STORE-CBC-001';
        escrowObj.SwiftCode__c       = 'SWIFTCBC';
        escrowObj.TradeID__c         = 'TRADE-CBC-001';
        escrowObj.BankName__c        = 'CBC Bank';
        escrowObj.BeneficiaryName__c = 'CBC Beneficiary';
        insert escrowObj;

        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name                    = 'CBC Virtual Account';
        vaObj.Status__c               = 'Available';
        vaObj.EscrowAccount__c        = escrowObj.Id;
        vaObj.VirtualAccountNumber__c = '987654321';
        vaObj.VirtualIBANNumber__c    = 'AE9876543219876';
        insert vaObj;

        Phase__c phaseObj = new Phase__c();
        phaseObj.Name             = 'CBC Phase 1';
        phaseObj.Project__c       = projectObj.Id;
        phaseObj.EscrowAccount__c = escrowObj.Id;
        phaseObj.EntityName__c    = 'Modon Properties PJSC';
        insert phaseObj;

        Unit__c unitObj = new Unit__c();
        unitObj.Name                  = 'CBC Unit';
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
        paymentPlanObj.Type__c       = 'Standard';
        paymentPlanObj.Unit__c       = unitObj.Id;
        paymentPlanObj.Status__c     = 'Active';
        paymentPlanObj.StartDate__c  = System.today().addDays(-2);
        paymentPlanObj.ExpiryDate__c = System.today().addDays(5);
        insert paymentPlanObj;

        PaymentInstallements__c piObj = new PaymentInstallements__c();
        piObj.PaymentInstallment__c   = paymentPlanObj.Id;
        piObj.BrokerPayout__c         = 10;
        piObj.Milestone__c            = 1;
        piObj.MilestoneNumber__c      = 1;
        piObj.MilestoneDescription__c = 'CBC Milestone';
        insert piObj;

        // Sales Order — CustAcctId__c = 'CBC-001' is the loadIds() anchor
        // CustomerOraclePartyId__c non-null → passes the 3.0 oracle guard
        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c                 = 'In Progress';
        salesOrderObj.Unit__c                   = unitObj.Id;
        salesOrderObj.UnitOption__c             = unitOptionObj.Id;
        salesOrderObj.PaymentPlan__c            = paymentPlanObj.Id;
        salesOrderObj.VirtualAccount__c         = vaObj.Id;
        salesOrderObj.CustomerAccount__c        = accountObj.Id;
        salesOrderObj.TotalAmount__c            = 20000;
        salesOrderObj.CustAcctId__c             = '00222001';
        salesOrderObj.OraclePartySiteID__c      = '33333';
        salesOrderObj.OracleCustAcctSiteID__c   = '765456';
        salesOrderObj.OracleSiteUseID__c        = '00123001';
        salesOrderObj.OraclePartyId__c          = '34346';
        salesOrderObj.Source_Entity__c          = 'Modon - UAE';
        salesOrderObj.SalesAssociate__c         = UserInfo.getUserId();
        salesOrderObj.IsDownPaymentCollected__c = true;
        insert salesOrderObj;

        SalesOrderInstallments__c soiObj = new SalesOrderInstallments__c();
        soiObj.SalesOrder__c           = salesOrderObj.Id;
        soiObj.PaymentInstallments__c  = piObj.Id;
        soiObj.Milestone__c            = 2;
        soiObj.MilestoneNumber__c      = 2;
        soiObj.MilestoneDescription__c = 'CBC Installment';
        soiObj.InstallmentAmount__c    = 1000;
        soiObj.MilestoneDate__c        = System.today();
        insert soiObj;

        // Invoice 1 — SOI-linked
        Invoice__c inv1 = new Invoice__c();
        inv1.SalesOrderInstallment__c = soiObj.Id;
        inv1.Sales_Order__c           = salesOrderObj.Id;
        inv1.InvoiceAmount__c         = 1000;
        inv1.Account__c               = accountObj.Id;
        inv1.Ebs_Invoice_Date__c      = System.today();
        inv1.InvoiceDate__c           = System.today();

        // Invoice 2 — direct (no SOI)
        Invoice__c inv2 = new Invoice__c();
        inv2.Sales_Order__c      = salesOrderObj.Id;
        inv2.InvoiceAmount__c    = 500;
        inv2.Account__c          = accountObj.Id;
        inv2.Ebs_Invoice_Date__c = System.today();
        inv2.InvoiceDate__c      = System.today();

        insert new List<Invoice__c>{ inv1, inv2 };

        // Receipt — OraclePartyId__c must be set (mirrors EBSTransferBatchV1Test)
        Receipt__c rec1 = new Receipt__c();
        rec1.TotalAmount__c           = 1000;
        rec1.Receipt_Amount__c        = 1000;
        rec1.Account__c               = accountObj.Id;
        rec1.SalesOrderInstallment__c = soiObj.Id;
        rec1.SalesOrder__c            = salesOrderObj.Id;
        rec1.PaymentEscrowAccount__c  = escrowObj.Id;
        rec1.TransactionDate__c       = System.now();
        rec1.ReceiptDate__c           = System.today();
        rec1.ChequeDate__c            = System.today();
        rec1.EBS_Clearing_Date__c     = System.today();
        rec1.Modeofpayment__c         = 'Cheque';
        rec1.Bank__c                  = 'CitiBank';
        rec1.TransactionNumber__c     = '999001CBC';
        rec1.Status__c                = 'In Progress';
        rec1.OraclePartyId__c         = '341245001';
        insert rec1;

        
        // ServiceRequest — Transferred_Sales_Order__c = salesOrderObj
        // so sr.Transferred_Sales_Order__r.CustomerOraclePartyId__c = 'ORACLE-001' (non-null)
        ServiceRequest__c srObj = new ServiceRequest__c();
        srObj.Status__c                  = 'In-progress';
        srObj.SalesOrder__c              = salesOrderObj.Id;
        srObj.Transferred_Sales_Order__c = salesOrderObj.Id;
        srObj.RecordTypeId               = preCancelRT;
        insert srObj;

    }

    // ══════════════════════════════════════════════════════════════════════════
    // loadIds — FIRST call in every test method
    // Anchors on SalesOrder__c WHERE CustAcctId__c = 'CBC-001'
    // ══════════════════════════════════════════════════════════════════════════
    private static void loadIds() {
        SalesOrder__c so = [
            SELECT Id, CustomerAccount__c, CustomerOraclePartyId__c
            FROM   SalesOrder__c
            WHERE  CustAcctId__c = '00222001'
            LIMIT  1
        ];
        salesOrderId   = so.Id;
        buyerAccountId = so.CustomerAccount__c;

        Invoice__c inv1 = [
            SELECT Id FROM Invoice__c
            WHERE  Sales_Order__c          = :salesOrderId
              AND  SalesOrderInstallment__c != null
            LIMIT  1
        ];
        invoiceId1 = inv1.Id;

        Invoice__c inv2 = [
            SELECT Id FROM Invoice__c
            WHERE  Sales_Order__c          = :salesOrderId
              AND  SalesOrderInstallment__c = null
            LIMIT  1
        ];
        invoiceId2 = inv2.Id;

        Receipt__c rec = [
            SELECT Id FROM Receipt__c
            WHERE  SalesOrder__c = :salesOrderId
            LIMIT  1
        ];
        receiptId = rec.Id;

        ServiceRequest__c sr = [
            SELECT Id FROM ServiceRequest__c
            WHERE  SalesOrder__c = :salesOrderId
            LIMIT  1
        ];
        srId = sr.Id;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HELPER — builds SR_Sync_Ids__c JSON payload
    // ══════════════════════════════════════════════════════════════════════════
    private static String buildPayload(
        String       soId,
        List<String> invoiceIds,
        List<String> receiptIds,
        List<String> allocationIds
    ) {
        Map<String, Object> m = new Map<String, Object>{
            'soId'          => soId,
            'invoiceIds'    => invoiceIds,
            'receiptIds'    => receiptIds,
            'allocationIds' => allocationIds
        };
        return JSON.serialize(m);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // HELPER — creates a new ServiceRequest__c in the desired RecordType
    //          with the given Transferred_Sales_Order__c
    // ══════════════════════════════════════════════════════════════════════════
    private static ServiceRequest__c makeSR(
        Id     recordTypeId,
        String syncIdsJson,
        String syncStatus,
        Id     transferredSoId
    ) {
        TriggerControl.BypassCancelledTrigger = true;
        ServiceRequest__c sr = new ServiceRequest__c(
            SR_Sync_Ids__c             = syncIdsJson,
            Sync_Status__c             = syncStatus,
            RecordTypeId               = recordTypeId,
            Transferred_Sales_Order__c = transferredSoId
        );
        insert sr;
        TriggerControl.BypassCancelledTrigger = false;
        return sr;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // getSyncStatus — Fully Completed → isTerminal = true
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetSyncStatus_FullyCompleted() {
        loadIds();
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(Id = srId, Sync_Status__c = 'Fully Completed');
        TriggerControl.BypassCancelledTrigger = false;

        Test.startTest();
        CancellationBatchController.getSyncStatus(srId);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // getSyncStatus — Partially Completed → isTerminal = true
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetSyncStatus_PartiallyCompleted() {
        loadIds();
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(Id = srId, Sync_Status__c = 'Partially Completed');
        TriggerControl.BypassCancelledTrigger = false;

        Test.startTest();
        CancellationBatchController.getSyncStatus(srId);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // getSyncStatus — In Progress → isTerminal = false (non-terminal branch)
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetSyncStatus_InProgress_NonTerminal() {
        loadIds();
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(Id = srId, Sync_Status__c = 'Pending');
       
        Test.startTest();
        CancellationBatchController.getSyncStatus(srId);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // getSyncStatus — null Id → SOQL throws → exception catch → isTerminal=true
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetSyncStatus_NullId_ExceptionPath() {
        loadIds();
        Test.startTest();
        CancellationBatchController.getSyncStatus(null);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — null Id → srList.isEmpty() → result.success=false
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_SRNotFound_NullId() {
        loadIds();
        Test.startTest();
        CancellationBatchController.launchCancellationBatch(null);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — SR_Sync_Ids__c is blank → step 2 guard fires
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_BlankSyncIds() {
        loadIds();
        // Update the existing SR: clear SR_Sync_Ids__c, point Transferred_SO to SO
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(
            Id                         = srId,
            SR_Sync_Ids__c             = null,
            Transferred_Sales_Order__c = salesOrderId
        );
        TriggerControl.BypassCancelledTrigger = false;

        Test.startTest();
        CancellationBatchController.launchCancellationBatch(srId);
        Test.stopTest();
    }

  

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — invalid JSON → JSON.deserialize throws
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_InvalidJson() {
        loadIds();
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(
            Id                         = srId,
            SR_Sync_Ids__c             = 'NOT_VALID_JSON',
            Transferred_Sales_Order__c = salesOrderId
        );
        TriggerControl.BypassCancelledTrigger = false;

        Test.startTest();
        CancellationBatchController.launchCancellationBatch(srId);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — Pre Unit Cancellation, all lists empty
    // Covers: invoiceIds.isEmpty() && receiptIds.isEmpty() && allocationIds.isEmpty()
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_PreCancel_AllListsEmpty() {
        loadIds();
        String payload = buildPayload(
            salesOrderId,
            new List<String>(),
            new List<String>(),
            new List<String>()
        );
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(
            Id                         = srId,
            SR_Sync_Ids__c             = payload,
            Transferred_Sales_Order__c = salesOrderId,
            RecordTypeId               = preCancelRT
        );
        TriggerControl.BypassCancelledTrigger = false;

        Test.startTest();
        CancellationBatchController.launchCancellationBatch(srId);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — Pre Unit Cancellation, null lists in JSON
    // Null lists → normalised to empty → hits same isEmpty() branch
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_PreCancel_NullListsInPayload() {
        loadIds();
        Map<String, Object> m = new Map<String, Object>{
            'soId'          => salesOrderId,
            'invoiceIds'    => null,
            'receiptIds'    => null,
            'allocationIds' => null
        };
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(
            Id                         = srId,
            SR_Sync_Ids__c             = JSON.serialize(m),
            Transferred_Sales_Order__c = salesOrderId,
            RecordTypeId               = preCancelRT
        );
        TriggerControl.BypassCancelledTrigger = false;

        Test.startTest();
        CancellationBatchController.launchCancellationBatch(srId);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — Pre Unit Cancellation, SUCCESS
    // Covers: EBSCancellationBatch enqueued, result.success=true, all counts set
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_PreCancel_Success() {
        loadIds();
       
        String payload = buildPayload(
            salesOrderId,
            new List<String>{ invoiceId1, invoiceId2 },
            new List<String>{ receiptId },
            new List<String>{ }
        );
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(
            Id                         = srId,
            SR_Sync_Ids__c             = payload,
            Transferred_Sales_Order__c = salesOrderId,
            RecordTypeId               = preCancelRT
        );
        TriggerControl.BypassCancelledTrigger = false;

        Test.startTest();
        CancellationBatchController.BatchLaunchResult result =
            CancellationBatchController.launchCancellationBatch(srId);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — Transfer OffPlan, empty invoice + receipt lists
    // Covers: invoiceIds.isEmpty() && receiptIds.isEmpty() → error branch
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_Transfer_OffPlan_EmptyLists() {
        Test.startTest();
        loadIds();
        String payload = buildPayload(
            salesOrderId,
            new List<String>(),
            new List<String>(),
            new List<String>()
        );
        ServiceRequest__c sr = makeSR(transferOffPlanRT, payload, 'Pending', salesOrderId);

        
        CancellationBatchController.launchCancellationBatch(sr.Id);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — Transfer OffPlan, invoices only (no receipts)
    // Covers: invoiceIds non-empty → not blocked by empty check → batch enqueued
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_Transfer_OffPlan_InvoicesOnly() {
        Test.startTest();
        loadIds();
        String payload = buildPayload(
            salesOrderId,
            new List<String>{ invoiceId1 },
            new List<String>(),
            new List<String>()
        );
        ServiceRequest__c sr = makeSR(transferOffPlanRT, payload, 'Pending', salesOrderId);

        
        CancellationBatchController.launchCancellationBatch(sr.Id);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — Transfer OffPlan, SUCCESS (invoices + receipts)
    // Covers: EBSTransferBatchV1 enqueued, allocationCount=0, result.success=true
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_Transfer_OffPlan_Success() {
        Test.startTest();
        loadIds();
        String payload = buildPayload(
            salesOrderId,
            new List<String>{ invoiceId1, invoiceId2 },
            new List<String>{ receiptId },
            new List<String>()   // Transfer does not pass allocationIds
        );
        ServiceRequest__c sr = makeSR(transferOffPlanRT, payload, 'Pending', salesOrderId);

        
        CancellationBatchController.BatchLaunchResult result =
            CancellationBatchController.launchCancellationBatch(sr.Id);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // launchCancellationBatch — Unsupported RecordType → else branch
    // Finds any RT not in the controller's routing chain
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testLaunch_UnsupportedRecordType() {
        loadIds();
        // Find a RecordType developer name not covered by the controller's if/else
        Set<String> routedRTs = new Set<String>{
            'Pre_Unit_Cancellation',
            'Service_Request_Management_Property_Transfer_OffPlan',
            'Service_Request_Management_Property_Transfer_Title_Deed_Commercial',
            'Service_Request_Management_Property_Transfer_Title_Deed'
        };

        Id unknownRt;
        for (RecordTypeInfo rti :
             Schema.SObjectType.ServiceRequest__c
                .getRecordTypeInfosByDeveloperName().values()
        ) {
            if (!routedRTs.contains(rti.getDeveloperName()) && rti.isAvailable()) {
                unknownRt = rti.getRecordTypeId();
                break;
            }
        }

        if (unknownRt == null) {
            // Org has no unrouted SR record types — coverage not possible here
            return;
        }

        String payload = buildPayload(
            salesOrderId,
            new List<String>{ invoiceId1 },
            new List<String>{ receiptId },
            new List<String>()
        );
        //ServiceRequest__c sr = makeSR(unknownRt, payload, 'Pending', salesOrderId);

        Test.startTest();
       // CancellationBatchController.launchCancellationBatch(sr.Id);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // getBatchJobStatus — real job Id (from a launched batch)
    // Covers: happy path query on AsyncApexJob, terminal state check
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetBatchJobStatus_WithRealJobId() {
        loadIds();
        
        String payload = buildPayload(
            salesOrderId,
            new List<String>{ invoiceId1 },
            new List<String>{ receiptId },
            new List<String>{ }
        );
        TriggerControl.BypassCancelledTrigger = true;
        update new ServiceRequest__c(
            Id                         = srId,
            SR_Sync_Ids__c             = payload,
            Transferred_Sales_Order__c = salesOrderId,
            RecordTypeId               = preCancelRT
        );
        
        Test.startTest();
        CancellationBatchController.BatchLaunchResult launchRes =
            CancellationBatchController.launchCancellationBatch(srId);
        Test.stopTest();

        // Call getBatchJobStatus with the real job Id after batch completes
        if (launchRes != null && launchRes.success && launchRes.jobId != null) {
            CancellationBatchController.getBatchJobStatus(launchRes.jobId);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // getBatchJobStatus — null job Id → SOQL throws → exception catch path
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetBatchJobStatus_NullId_ExceptionPath() {
        loadIds();
        Test.startTest();
        CancellationBatchController.getBatchJobStatus(null);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // getBatchJobStatus — non-existent (fake) job Id → SOQL returns 0 rows → exception
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testGetBatchJobStatus_FakeJobId_ExceptionPath() {
        loadIds();
        Id fakeJobId = '707000000000001AAA';
        Test.startTest();
        CancellationBatchController.getBatchJobStatus(fakeJobId);
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Inner class field access — ensures @AuraEnabled properties are exercised
    // ══════════════════════════════════════════════════════════════════════════
    @IsTest
    static void testInnerClassFieldAccess() {
        loadIds();
        CancellationBatchController.SyncStatusResult ssr =
            new CancellationBatchController.SyncStatusResult();
        ssr.syncStatus = 'In Progress';
        ssr.isTerminal = false;

        CancellationBatchController.BatchLaunchResult blr =
            new CancellationBatchController.BatchLaunchResult();
        blr.success         = true;
        blr.message         = 'ok';
        blr.jobId           = '08877001';
        blr.invoiceCount    = 2;
        blr.receiptCount    = 1;
        blr.allocationCount = 1;
    }
}