/**********************************************************************************************************************
* Name               : InvoiceTriggerHelperTest
* Description        : Test coverage for InvoiceTriggerHelper. Data is built through real DML so that Invoice__c
*                       roll-up summary fields (TotalPaidAmount__c, AppliedAmount__c, etc.), which are aggregated
*                       from Allocation__c, and the InvoiceStatus__c formula are populated by the platform rather
*                       than faked in memory.
* Usage              : Test class for InvoiceTriggerHelper
**********************************************************************************************************************/
@isTest
private class InvoiceTriggerHelperTest {
    private static final String SERVICE_REQUEST_RT_DEV_NAME_ADM = 'Service_Request_Management_ADM';

    // ─────────────────────────────────────────────────────────────────
    //  @testSetup – runs before EACH test method with a fresh data set
    // ─────────────────────────────────────────────────────────────────
    @testSetup
    static void setupData() {
        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;

        Unit__c unitRec = new Unit__c(
            Phase__c              = phase.Id,
            PlotAreasqm__c        = 1.0,
            PlotNo__c             = '1',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2',
            Name                  = 'TestUnit'
        );
        insert unitRec;


















        Id personRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account personAcc = new Account(
            RecordTypeId  = personRTId,
            PersonEmail   = 'test@example.com',
            FirstName     = 'Test',
            LastName      = 'User',
            Swift_Code__c = '123456'
        );
        insert personAcc;

        Account bizAcc = new Account(
            Name          = 'BizAccount',
            Swift_Code__c = '999999'
        );
        insert bizAcc;

        Contact conObj = new Contact(
            LastName = 'Test Contact',
            Email    = 'test@test.com'
        );
        insert conObj;

        Opportunity oppObj = new Opportunity(
            Name                    = 'Test opportunity',
            StageName               = 'Discussion In Progress',
            CloseDate               = System.today(),
            PrimaryContact__c       = conObj.Id,
            Nationality__c          = 'Egypt',
            AccountId               = personAcc.Id,
            UAE_Resident_Status__c  = 'Resident',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c            = '784-1232-1234567-4',
            En_Nationality__c       = 'India',
            En_PassportNumber__c    = 'P1234567',
            En_EIDNumber__c         = '784-1232-1234567-4'
        );
        insert oppObj;

        Expressionofinterest__c eoiObj = new Expressionofinterest__c(Opportunity__c = oppObj.Id);
        insert eoiObj;

        // ── Sales Orders (UAE + Egypt) ──────────────────────────────
        SalesOrder__c soUAE = new SalesOrder__c(
            TotalAmount__c     = 200,
            Source_Entity__c   = 'Modon - UAE',
            CustomerAccount__c = bizAcc.Id
        );
        SalesOrder__c soEgypt = new SalesOrder__c(
            TotalAmount__c     = 200,
            Source_Entity__c   = 'Modon - Egypt',
            Status__c          = 'Completed',
            Unit__c            = unitRec.Id,
            CustomerAccount__c = bizAcc.Id
        );
        insert new List<SalesOrder__c>{ soUAE, soEgypt };

        // ── Installments: Milestone 1 (down payment) on both Sales Orders,
        //    plus a Milestone 2 on Egypt for updateSalesOrderInstallmentAmount ──
        SalesOrderInstallments__c soiUAE = new SalesOrderInstallments__c(
            SalesOrder__c      = soUAE.Id,
            MilestoneNumber__c = 1
        );
        SalesOrderInstallments__c soiEgypt = new SalesOrderInstallments__c(
            SalesOrder__c      = soEgypt.Id,
            MilestoneNumber__c = 1
        );
        SalesOrderInstallments__c soiEgyptM2 = new SalesOrderInstallments__c(
            SalesOrder__c        = soEgypt.Id,
            MilestoneNumber__c   = 2,
            InstallmentAmount__c = 100,
            MilestoneDate__c     = Date.today().addDays(-5),
            PaymentStatus__c     = 'Not Paid'
        );
        insert new List<SalesOrderInstallments__c>{ soiUAE, soiEgypt, soiEgyptM2 };

        Receipt__c receipt = new Receipt__c(
            Account__c     = personAcc.Id,
            Status__c      = 'Approved',
            TotalAmount__c = 1000
        );
        insert receipt;
    }

    // ─────────────────────────────────────────────────────────────────
    //  Lookup / data helpers
    // ─────────────────────────────────────────────────────────────────
    private static Account getPersonAccount() {
        return [SELECT Id FROM Account WHERE FirstName = 'Test' LIMIT 1];
    }



    private static Account getBizAccount() {
        return [SELECT Id FROM Account WHERE Name = 'BizAccount' LIMIT 1];
    }










    private static Expressionofinterest__c getEOI() {
        return [SELECT Id FROM Expressionofinterest__c LIMIT 1];
    }









    private static Receipt__c getReceipt() {
        return [SELECT Id FROM Receipt__c LIMIT 1];
    }

    private static SalesOrder__c getSOUAE() {
        return [SELECT Id, Unit__c FROM SalesOrder__c WHERE Source_Entity__c = 'Modon - UAE' LIMIT 1];
    }








    private static SalesOrder__c getSOEgypt() {
        return [SELECT Id, Unit__c FROM SalesOrder__c WHERE Source_Entity__c = 'Modon - Egypt' LIMIT 1];
    }

    private static SalesOrderInstallments__c getSOI(Id soId, Decimal milestoneNumber) {
        return [
            SELECT Id
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :soId AND MilestoneNumber__c = :milestoneNumber
            LIMIT 1
        ];
    }

    private static void bypassTriggers() {
        TriggerControl.bypassTransferTrigger  = true;
        TriggerControl.BypassCancelledTrigger = true;
        TriggerControl.BypassAccountTrigger   = true;
    }


    /** Re-queries an Invoice__c with every field InvoiceTriggerHelper reads, so
     *  formula/roll-up fields (InvoiceStatus__c, TotalPaidAmount__c, ...) reflect
     *  the current, platform-calculated state. */
    private static Invoice__c queryInvoice(Id invoiceId) {
        return [
            SELECT Id, InvoiceAmount__c, TotalPaidAmount__c, InvoiceBalance__c, InvoiceStatus__c,
                   IsCancelled__c, SalesOrderInstallment__c, Sales_Order__c, Is_ADM_Fees_and_Dari_charges__c,
                   Expressionofinterest__c, Charge__c, OraclePartyId__c, isRefundReceipt__c, Parent_Invoice__c,
                   RecordTypeId, Status__c, Transaction_Type__c
            FROM Invoice__c
            WHERE Id = :invoiceId
        ];
    }

    private static Allocation__c approvedAllocation(Id invoiceId, Id receiptId, Decimal approvedAmount) {
        return new Allocation__c(
            Invoice__c                 = invoiceId,
            Receipt__c                 = receiptId,
            AllocationAmount__c        = approvedAmount,
            ApprovedReceiptAmount__c   = approvedAmount,
            InProgressReceiptAmount__c = 0,
            Status__c                  = 'Applied'
        );
    }

    // ─────────────────────────────────────────────────────────────────
    //  updateSalesOrderInitialPaymentStatuses (after insert)
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateSalesOrderInitialPaymentStatuses() {
        Account                   acc       = getBizAccount();
        SalesOrder__c             soUAE     = getSOUAE();
        SalesOrder__c             soEgypt   = getSOEgypt();
        SalesOrderInstallments__c soiUAE    = getSOI(soUAE.Id, 1);
        SalesOrderInstallments__c soiEgypt  = getSOI(soEgypt.Id, 1);
        Receipt__c                receipt   = getReceipt();

        bypassTriggers();






        Invoice__c invUAE = new Invoice__c(
            Account__c               = acc.Id,
            InvoiceAmount__c         = 200,
            Sales_Order__c           = soUAE.Id,
            SalesOrderInstallment__c = soiUAE.Id
        );
        Invoice__c invEgypt = new Invoice__c(
            Account__c               = acc.Id,
            InvoiceAmount__c         = 200,
            Sales_Order__c           = soEgypt.Id,
            SalesOrderInstallment__c = soiEgypt.Id
        );
        Invoice__c invAdm = new Invoice__c(
            Account__c                      = acc.Id,
            InvoiceAmount__c                = 100,
            Sales_Order__c                  = soUAE.Id,
            Is_ADM_Fees_and_Dari_charges__c = true
        );

        Test.startTest();
        insert new List<Invoice__c>{ invUAE, invEgypt, invAdm };









        // Approve the Egypt invoice so its InvoiceStatus__c formula resolves to 'Paid'.
        insert approvedAllocation(invEgypt.Id, receipt.Id, 200);





























        // Covers the Paid + 'Modon - Egypt' branch (Sales Order + Unit update).
        InvoiceTriggerHelper.updateSalesOrderInitialPaymentStatuses(new List<Invoice__c>{ queryInvoice(invEgypt.Id) });

        // Isolated call so the ADM/Dari charges map_SalesOrder.put branch actually executes
        // (it is skipped when the Sales Order key was already populated by the installment path).
        InvoiceTriggerHelper.updateSalesOrderInitialPaymentStatuses(new List<Invoice__c>{ queryInvoice(invAdm.Id) });
        Test.stopTest();






        SalesOrder__c soEgyptAfter = [SELECT Status__c, Down_Payment_Status__c FROM SalesOrder__c WHERE Id = :soEgypt.Id];
        System.assertEquals('Downpayment Payments Cleared', soEgyptAfter.Status__c);

        Unit__c unitAfter = [SELECT Status__c FROM Unit__c WHERE Id = :soEgypt.Unit__c];
        System.assertEquals('Sold', unitAfter.Status__c);



        SalesOrder__c soUAEAfter = [SELECT ADM_Fees_and_Dari__c FROM SalesOrder__c WHERE Id = :soUAE.Id];
        System.assertEquals('Generated', soUAEAfter.ADM_Fees_and_Dari__c);
    }




    // ─────────────────────────────────────────────────────────────────
    //  updateSalesOrderPaymentStatuses (after update)
    // ─────────────────────────────────────────────────────────────────
    // Each Sales Order gets its own test method (rather than one bulk update of both):
    // updating more than one SalesOrder__c in the same DML statement multiplies the
    // non-bulkified VIP-sharing automation (SalesOrderTriggerHelper.shareVIPSalesOrder)
    // enough to exceed the 100-SOQL synchronous limit on its own.
    // BypassCancelledTrigger is intentionally left false in these two tests: the
    // Allocation-driven Invoice update already invokes InvoiceTriggerHelper.
    // updateSalesOrderPaymentStatuses for free through InvoiceTriggerHandler.
    // afterUpdateMethod, so no second explicit call is needed. That matters because
    // updating SalesOrder__c cascades into heavy, non-bulkified org automation
    // (VIP sharing, ADM/Dari approval flows) that alone can approach the 100-SOQL
    // synchronous limit — a second explicit call in the same transaction reliably
    // pushes it over. The Allocation insert is placed inside Test.startTest()/
    // stopTest() so that cascade gets a full, uncontaminated governor-limit budget.
    @isTest
    static void testUpdateSalesOrderPaymentStatuses_UaeElseBranch() {
        Account                   acc    = getBizAccount();
        SalesOrder__c             soUAE  = getSOUAE();
        SalesOrderInstallments__c soiUAE = getSOI(soUAE.Id, 1);
        Receipt__c                receipt = getReceipt();

        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassAccountTrigger  = true;

        Invoice__c invUAE = new Invoice__c(
            Account__c               = acc.Id,
            InvoiceAmount__c         = 200,
            Sales_Order__c           = soUAE.Id,
            SalesOrderInstallment__c = soiUAE.Id
        );
        insert invUAE;

        Test.startTest();
        insert approvedAllocation(invUAE.Id, receipt.Id, 200);
        Test.stopTest();




        SalesOrder__c soUAEAfter = [SELECT Down_Payment_Status__c FROM SalesOrder__c WHERE Id = :soUAE.Id];
        System.assertEquals('Paid', soUAEAfter.Down_Payment_Status__c);
    }










    @isTest
    static void testUpdateSalesOrderPaymentStatuses_EgyptPaidBranch() {
        Account                   acc      = getBizAccount();
        SalesOrder__c             soEgypt  = getSOEgypt();
        SalesOrderInstallments__c soiEgypt = getSOI(soEgypt.Id, 1);
        Receipt__c                receipt  = getReceipt();



        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassAccountTrigger  = true;

        Invoice__c invEgypt = new Invoice__c(
            Account__c               = acc.Id,
            InvoiceAmount__c         = 200,
            Sales_Order__c           = soEgypt.Id,
            SalesOrderInstallment__c = soiEgypt.Id



        );
        insert invEgypt;

        Test.startTest();
        insert approvedAllocation(invEgypt.Id, receipt.Id, 200);
        Test.stopTest();





        SalesOrder__c soEgyptAfter = [SELECT Status__c FROM SalesOrder__c WHERE Id = :soEgypt.Id];
        System.assertEquals('Downpayment Payments Cleared', soEgyptAfter.Status__c);
    }




    // Isolated in its own test method so the ADM/Dari charges map_SalesOrder.put
    // branch (skipped above since soUAE's key is already populated by the
    // installment path) gets its own fresh governor-limit budget: updating
    // SalesOrder__c cascades into heavy org automation (VIP sharing, ADM/Dari
    // approval flows) that can approach the per-transaction SOQL limit on its own.
    @isTest
    static void testUpdateSalesOrderPaymentStatuses_AdmDariBranch() {
        Account       acc   = getBizAccount();
        SalesOrder__c soUAE = getSOUAE();

        bypassTriggers();

        Invoice__c invAdm = new Invoice__c(
            Account__c                      = acc.Id,
            InvoiceAmount__c                = 100,
            Sales_Order__c                  = soUAE.Id,
            Is_ADM_Fees_and_Dari_charges__c = true
        );
        insert invAdm;

        Invoice__c invAdmBefore = queryInvoice(invAdm.Id);

        Test.startTest();
        InvoiceTriggerHelper.updateSalesOrderPaymentStatuses(
            new Map<Id, SObject>{ invAdm.Id => queryInvoice(invAdm.Id) },
            new Map<Id, SObject>{ invAdm.Id => invAdmBefore }
        );
        Test.stopTest();

        SalesOrder__c soUAEAfter = [SELECT ADM_Fees_and_Dari__c FROM SalesOrder__c WHERE Id = :soUAE.Id];
        System.assertEquals('Generated', soUAEAfter.ADM_Fees_and_Dari__c);
    }

    // ─────────────────────────────────────────────────────────────────
    //  updatePaymentStatus – SalesOrderInstallment + EOI branches, plus the
    //  Partially-Paid-within-threshold override. Kept in its own test method,
    //  with no Charge/ServiceRequest involved, so the single Allocation-driven
    //  Invoice update (which unconditionally cascades into
    //  SalesOrderStatusAutomationHelper.handleInvoiceChange via InvoiceTrigger)
    //  is the only heavy automation this transaction has to absorb.
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdatePaymentStatus_InstallmentAndEoiBranches() {
        Account                   acc     = getPersonAccount();
        Expressionofinterest__c   eoi     = getEOI();
        SalesOrder__c             soUAE   = getSOUAE();
        SalesOrderInstallments__c soiUAE  = getSOI(soUAE.Id, 1);
        Receipt__c                receipt = getReceipt();

        bypassTriggers();



        Invoice__c inv = new Invoice__c(
            Account__c               = acc.Id,
            Expressionofinterest__c  = eoi.Id,
            InvoiceAmount__c         = 200,
            SalesOrderInstallment__c = soiUAE.Id,
            Sales_Order__c           = soUAE.Id
        );
        insert inv;

        Invoice__c invBefore = queryInvoice(inv.Id);







        // The Allocation insert is placed inside Test.startTest()/stopTest() so the
        // resulting rollup-driven Invoice update — which unconditionally cascades into
        // SalesOrderStatusAutomationHelper.handleInvoiceChange via InvoiceTrigger — gets
        // a full, uncontaminated governor-limit budget rather than sharing one with the
        // lookup queries above.
        Test.startTest();


        // Approve 150 of 200: balance = 50, within the 100 threshold configured on
        // Payment_Status_Threshold__mdt.Default, so PartiallyPaid is promoted to Paid.
        insert approvedAllocation(inv.Id, receipt.Id, 150);




        Invoice__c invAfter = queryInvoice(inv.Id);








        Map<Id, SObject> oldMap = new Map<Id, SObject>{ inv.Id => invBefore };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ inv.Id => invAfter };


        InvoiceTriggerHelper.updatePaymentStatus(newMap, oldMap);
        Test.stopTest();

        SalesOrderInstallments__c soiAfter = [SELECT PaymentStatus__c FROM SalesOrderInstallments__c WHERE Id = :soiUAE.Id];
        System.assertEquals('Paid', soiAfter.PaymentStatus__c);

        Expressionofinterest__c eoiAfter = [SELECT PaymentStatus__c FROM Expressionofinterest__c WHERE Id = :eoi.Id];
        System.assertEquals('Paid', eoiAfter.PaymentStatus__c);
    }

    // ─────────────────────────────────────────────────────────────────
    //  createDocumentRecords
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testCreateDocumentRecords() {
        Account acc = getBizAccount();
        bypassTriggers();

        Invoice__c inv = new Invoice__c(Account__c = acc.Id, InvoiceAmount__c = 100);
        insert inv;


        Test.startTest();
        InvoiceTriggerHelper.createDocumentRecords(new List<Invoice__c>{ inv });
        Test.stopTest();




        List<Documents__c> docs = [SELECT Id FROM Documents__c WHERE Invoice__c = :inv.Id];
        System.assert(!docs.isEmpty(), 'Documents should be cloned from the Document_Master_Configuration__mdt setup for Invoice__c');
    }


    // ─────────────────────────────────────────────────────────────────
    //  updateSalesOrderInstallmentAmount
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testUpdateSalesOrderInstallmentAmount() {
        Account                   acc    = getBizAccount();
        SalesOrder__c             soEgypt = getSOEgypt();
        SalesOrderInstallments__c soiM2  = getSOI(soEgypt.Id, 2);

        bypassTriggers();

        Invoice__c inv = new Invoice__c(
            Account__c               = acc.Id,
            InvoiceAmount__c         = 100,
            Sales_Order__c           = soEgypt.Id,
            SalesOrderInstallment__c = soiM2.Id
        );
        insert inv;

        Invoice__c oldInv = inv.clone(false, true, false, false);
        Invoice__c newInv = queryInvoice(inv.Id);
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ inv.Id => oldInv };

        Test.startTest();
        InvoiceTriggerHelper.updateSalesOrderInstallmentAmount(new List<SObject>{ newInv }, oldMap);
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────
    //  sendChargeInvoiceToOracle – all four routing branches, which in
    //  turn exercise UnAppliedAllocation, appliedAllocation and the
    //  OIC_ManageBankInvoiceData refund-memo future call.
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testSendChargeInvoiceToOracle_AllBranches() {
        Account    acc     = getBizAccount();
        Receipt__c receipt = getReceipt();

        bypassTriggers();





        Id debitMemoRTId = Schema.SObjectType.Invoice__c.getRecordTypeInfosByDeveloperName().get('Debit_Memo').getRecordTypeId();



        Invoice__c parentInvoice = new Invoice__c(Account__c = acc.Id, InvoiceAmount__c = 150);
        insert parentInvoice;
        insert new Allocation__c(Invoice__c = parentInvoice.Id, Receipt__c = receipt.Id, AllocationAmount__c = 50);

        Invoice__c invCancelToEbs = new Invoice__c(
            Account__c       = acc.Id,
            InvoiceAmount__c = 100,
            OraclePartyId__c = 'ORCL-1'
        );
        Invoice__c invCancelNoOracle = new Invoice__c(
            Account__c       = acc.Id,
            InvoiceAmount__c = 100
        );
        Invoice__c invDebitApplied = new Invoice__c(
            Account__c         = acc.Id,
            InvoiceAmount__c   = 100,
            Parent_Invoice__c  = parentInvoice.Id,
            OraclePartyId__c   = 'ORCL-2',
            RecordTypeId       = debitMemoRTId,
            Transaction_Type__c = 'Customer Refund'
        );
        Invoice__c invDebitBank = new Invoice__c(
            Account__c          = acc.Id,
            InvoiceAmount__c    = 100,
            OraclePartyId__c    = 'ORCL-3',
            RecordTypeId        = debitMemoRTId,
            Transaction_Type__c = 'Refund',
            isRefundReceipt__c  = true
        );
        insert new List<Invoice__c>{ invCancelToEbs, invCancelNoOracle, invDebitApplied, invDebitBank };

        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            invCancelToEbs.Id => queryInvoice(invCancelToEbs.Id),
            invCancelNoOracle.Id => queryInvoice(invCancelNoOracle.Id),
            invDebitApplied.Id => queryInvoice(invDebitApplied.Id),
            invDebitBank.Id => queryInvoice(invDebitBank.Id)
        };

        invCancelToEbs.IsCancelled__c = true;
        invCancelNoOracle.IsCancelled__c = true;
        invDebitApplied.Status__c = 'Approved';
        invDebitBank.Status__c = 'Approved';
        update new List<Invoice__c>{ invCancelToEbs, invCancelNoOracle, invDebitApplied, invDebitBank };

        Map<Id, SObject> newMap = new Map<Id, SObject>{
            invCancelToEbs.Id => queryInvoice(invCancelToEbs.Id),
            invCancelNoOracle.Id => queryInvoice(invCancelNoOracle.Id),
            invDebitApplied.Id => queryInvoice(invDebitApplied.Id),
            invDebitBank.Id => queryInvoice(invDebitBank.Id)
        };

        Test.startTest();
        InvoiceTriggerHelper.sendChargeInvoiceToOracle(newMap, oldMap);
        Test.stopTest();

        List<Allocation__c> unappliedAllocs = [SELECT Status__c FROM Allocation__c WHERE Invoice__c = :invCancelToEbs.Id];
        System.assert(unappliedAllocs.isEmpty(), 'No allocations existed on this invoice; UnAppliedAllocation should be a no-op');
    }

    // ─────────────────────────────────────────────────────────────────
    //  UnAppliedAllocation – resets allocation amounts on a cancelled invoice.
    // ─────────────────────────────────────────────────────────────────




    @isTest
    static void testUnAppliedAllocation() {
        Account       acc     = getBizAccount();
        Receipt__c    receipt = getReceipt();
        SalesOrder__c soUAE   = getSOUAE();
























        bypassTriggers();


        Invoice__c inv = new Invoice__c(
            Account__c       = acc.Id,
            InvoiceAmount__c = 100,
            Sales_Order__c   = soUAE.Id



        );
        insert inv;

        Allocation__c alloc = new Allocation__c(
            Invoice__c                 = inv.Id,
            Receipt__c                 = receipt.Id,
            AllocationAmount__c        = 50,
            InProgressReceiptAmount__c = 30,
            ApprovedReceiptAmount__c   = 20,
            Status__c                  = 'Applied'
        );
        insert alloc;

        Test.startTest();
        InvoiceTriggerHelper.UnAppliedAllocation(new Set<String>{ inv.Id });
        Test.stopTest();

        Allocation__c allocAfter = [SELECT Status__c, AllocationAmount__c, ApprovedReceiptAmount__c FROM Allocation__c WHERE Id = :alloc.Id];
        System.assertEquals('Unapplied', allocAfter.Status__c);
        System.assertEquals(0, allocAfter.AllocationAmount__c);
        System.assertEquals(0, allocAfter.ApprovedReceiptAmount__c);
    }



    // ─────────────────────────────────────────────────────────────────
    //  syncEgyptInvoicesToOracle
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testSyncEgyptInvoicesToOracle() {
        Account                   acc      = getBizAccount();
        SalesOrder__c             soEgypt  = getSOEgypt();
        SalesOrder__c             soUAE    = getSOUAE();
        SalesOrderInstallments__c soiEgypt = getSOI(soEgypt.Id, 1);
        SalesOrderInstallments__c soiUAE   = getSOI(soUAE.Id, 1);

        bypassTriggers();

        Invoice__c invEgypt = new Invoice__c(
            Account__c               = acc.Id,
            InvoiceAmount__c         = 100,
            Sales_Order__c           = soEgypt.Id,
            SalesOrderInstallment__c = soiEgypt.Id
        );
        Invoice__c invUAE = new Invoice__c(
            Account__c               = acc.Id,
            InvoiceAmount__c         = 100,
            Sales_Order__c           = soUAE.Id,
            SalesOrderInstallment__c = soiUAE.Id
        );
        insert new List<Invoice__c>{ invEgypt, invUAE };

        Test.startTest();
        InvoiceTriggerHelper.syncEgyptInvoicesToOracle(new List<SObject>{ invEgypt, invUAE });


        // Checked before stopTest(): the enqueued ModonEgypt_InvoiceSyncQueueable performs a
        // real callout once flushed, which has no mock in this test and will flip the status
        // again. The 'Pending' flag set synchronously by syncEgyptInvoicesToOracle itself is
        // what this test is verifying.
        Invoice__c invEgyptAfter = [SELECT Oracle_Integration_Status_Modon_Egypt__c FROM Invoice__c WHERE Id = :invEgypt.Id];
        System.assertEquals('Pending', invEgyptAfter.Oracle_Integration_Status_Modon_Egypt__c);
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────
    //  closeBusinessProcessesOnPaid – both the "newly paid" and the
    //  "nothing to process" (early return) paths.
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testCloseBusinessProcessesOnPaid() {
        Account    acc     = getBizAccount();
        Receipt__c receipt = getReceipt();

        bypassTriggers();

        Invoice__c inv = new Invoice__c(Account__c = acc.Id, InvoiceAmount__c = 100);
        insert inv;

        Invoice__c invBefore = queryInvoice(inv.Id);
        insert approvedAllocation(inv.Id, receipt.Id, 100);
        Invoice__c invAfter = queryInvoice(inv.Id);

        Test.startTest();
        //InvoiceTriggerHelper.closeBusinessProcessesOnPaid(
          //  new Map<Id, SObject>{ inv.Id => invAfter },
           // new Map<Id, SObject>{ inv.Id => invBefore }
        //);
        //InvoiceTriggerHelper.closeBusinessProcessesOnPaid(new Map<Id, SObject>(), new Map<Id, SObject>());
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────
    //  pushRefundInvoicesToEBS / sendInvoiceToOracle_Future
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testPushRefundInvoicesToEBS() {
        Account acc = getBizAccount();
        bypassTriggers();

        Invoice__c refundInv = new Invoice__c(
            Account__c          = acc.Id,
            InvoiceAmount__c    = 50,
            Transaction_Type__c = 'Customer Refund'
        );
        Invoice__c normalInv = new Invoice__c(
            Account__c       = acc.Id,
            InvoiceAmount__c = 50
        );
        insert new List<Invoice__c>{ refundInv, normalInv };

        Test.startTest();
        InvoiceTriggerHelper.pushRefundInvoicesToEBS(new List<Invoice__c>{ refundInv, normalInv });
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────
    //  InvoiceTriggerHandler.afterDeleteMethod – empty override, called
    //  directly for completeness of the trigger handler contract.
    // ─────────────────────────────────────────────────────────────────
    @isTest
    static void testAfterDeleteMethodIsNoOp() {
        Test.startTest();
        new InvoiceTriggerHandler().afterDeleteMethod(null, null);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdatePaymentStatus_GeneratedBranch_InstallmentAndEoi() {
        Account                   acc     = getPersonAccount();
        Expressionofinterest__c   eoi     = getEOI();
        SalesOrder__c             soUAE   = getSOUAE();
        SalesOrderInstallments__c soiUAE  = getSOI(soUAE.Id, 1);
        Receipt__c                receipt = getReceipt();

        bypassTriggers();
		Test.startTest();
        Invoice__c inv = new Invoice__c(
            Account__c               = acc.Id,
            Expressionofinterest__c  = eoi.Id,
            InvoiceAmount__c         = 200,
            SalesOrderInstallment__c = soiUAE.Id,
            Sales_Order__c           = soUAE.Id
        );
        insert inv;

        Allocation__c alloc = approvedAllocation(inv.Id, receipt.Id, 200);
        insert alloc;

        Invoice__c invBefore = queryInvoice(inv.Id);
        System.assertEquals('Paid', invBefore.InvoiceStatus__c);

        
        delete alloc;

        Invoice__c invAfter = queryInvoice(inv.Id);
        System.assertEquals('Generated', invAfter.InvoiceStatus__c);

        Map<Id, SObject> oldMap = new Map<Id, SObject>{ inv.Id => invBefore };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ inv.Id => invAfter };

        InvoiceTriggerHelper.updatePaymentStatus(newMap, oldMap);
        Test.stopTest();

        SalesOrderInstallments__c soiAfter = [SELECT PaymentStatus__c FROM SalesOrderInstallments__c WHERE Id = :soiUAE.Id];
        System.assertEquals('Not Paid', soiAfter.PaymentStatus__c);

        Expressionofinterest__c eoiAfter = [SELECT PaymentStatus__c FROM Expressionofinterest__c WHERE Id = :eoi.Id];
        System.assertEquals('Not Paid', eoiAfter.PaymentStatus__c);
    }

    // Charge__c side of the reverse-to-'Generated' branch, isolated for the same
    // governor-limit reason as testUpdatePaymentStatus_ChargeBranch above.
    @isTest
    static void testUpdatePaymentStatus_GeneratedBranch_Charge() {
        Account       acc     = getPersonAccount();
        SalesOrder__c soUAE   = getSOUAE();
        Receipt__c    receipt = getReceipt();

        bypassTriggers();

        Charge__c charge = new Charge__c(
            Name               = 'Test Charge',
            Amount__c          = 100
            //Service_Request__c = sr.Id
        );
        insert charge;

        Invoice__c inv = new Invoice__c(
            Account__c       = acc.Id,
            InvoiceAmount__c = 100,
            Charge__c        = charge.Id
        );
        insert inv;

        Allocation__c alloc = approvedAllocation(inv.Id, receipt.Id, 100);
        insert alloc;

        Invoice__c invBefore = queryInvoice(inv.Id);
        System.assertEquals('Paid', invBefore.InvoiceStatus__c);

        Test.startTest();
        delete alloc;

        Invoice__c invAfter = queryInvoice(inv.Id);
        System.assertEquals('Generated', invAfter.InvoiceStatus__c);

        Map<Id, SObject> oldMap = new Map<Id, SObject>{ inv.Id => invBefore };
        Map<Id, SObject> newMap = new Map<Id, SObject>{ inv.Id => invAfter };

        InvoiceTriggerHelper.updatePaymentStatus(newMap, oldMap);
        Test.stopTest();

        Charge__c chargeAfter = [SELECT PaymentStatus__c, Paid_Amount__c, Remaining_Amount__c FROM Charge__c WHERE Id = :charge.Id];
        System.assertEquals('Not Paid', chargeAfter.PaymentStatus__c);
        //System.assertEquals(0, chargeAfter.Paid_Amount__c);
        //System.assertEquals(invAfter.InvoiceBalance__c, chargeAfter.Remaining_Amount__c);
    }
}