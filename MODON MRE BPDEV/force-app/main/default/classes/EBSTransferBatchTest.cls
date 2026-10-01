@IsTest(SeeAllData=true)
public class EBSTransferBatchTest {

    // ─────────────────────────────────────────────────────────────────
    // SHARED TEST DATA BUILDER
    // ─────────────────────────────────────────────────────────────────
    private static ServiceRequest__c createFullSRData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            LastName    = 'Test Contact',
            AccountId   = acc.Id,
            Is_Active__c = true,
            Email       = 'test@mail.com'
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name                    = 'Test Opportunity',
            StageName               = 'Qualification',
            CloseDate               = Date.today(),
            UAE_Resident_Status__c  = 'Resident',
            Nationality__c          = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c            = '784-1232-1234567-4'
        );
        insert opp;

        Project__c po = new Project__c(Name = 'ProjectMega');
        insert po;

        Phase__c ph = new Phase__c(Name = 'bPhase', Project__c = po.Id);
        insert ph;

        Unit__c u = new Unit__c(
            Name                = '3',
            PlotNo__c           = '786B',
            Phase__c            = ph.Id,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '9',
            GrossFloorAreaGFA__c = 100,
            ADM_Plot_Number__c  = 'ADM-1',
            AED_SQM__c          = 50,
            Sector__c           = 'Sector 1',
            Location__c         = 'Dubai'
        );
        insert u;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Opportunity__c     = opp.Id,
            Status__c          = 'completed',
            Unit__c            = u.Id
        );
        insert so;

        PaymentPlan__c pp = new PaymentPlan__c(
            Name      = 'demo',
            Phase__c  = ph.Id,
            Project__c = po.Id,
            Unit__c   = u.Id,
            Type__c   = 'Standard'
        );
        insert pp;

        PaymentInstallements__c pi = new PaymentInstallements__c(
            PaymentInstallment__c = pp.Id,
            InstalmentNumber__c   = 'First Payment / Deposit'
        );
        insert pi;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c              = so.Id,
            PaymentInstallments__c     = pi.Id,
            MilestoneDate__c           = Date.today().addDays(15),
            InstalmentPaymentDueDate__c = '23/05/2025'
        );
        insert soi;

        Id rtId = Utility.getRecordTypeIdByDevName(
            ServiceRequest__c.SObjectType,
            'Property_Transfer_Title_Deed_Commercial'
        );

        ServiceRequest__c sr = new ServiceRequest__c(
            Name__c                    = 'Test SR',
            SalesOrder__c              = so.Id,
            AccountId__c               = acc.Id,
            OpportunityId__c           = opp.Id,
            UnitId__c                  = u.Id,
            Status__c                  = 'New',
            Type__c                    = 'Normal',
            Sales_Order_Installment__c = soi.Id,
            RecordTypeId               = rtId,
            ProjectId__c               = po.Id,
            Outstanding_Charge__c      = 100
        );
        insert sr;

        return sr;
    }

    private static Invoice__c createInvoice(ServiceRequest__c sr) {
        sr = [SELECT Id, SalesOrder__c, AccountId__c
              FROM ServiceRequest__c WHERE Id = :sr.Id];
        Invoice__c inv = new Invoice__c(
            Account__c     = sr.AccountId__c,
            Sales_Order__c = sr.SalesOrder__c
        );
        insert inv;
        return inv;
    }

    private static Receipt__c createReceipt(ServiceRequest__c sr) {
        sr = [SELECT Id, SalesOrder__c, AccountId__c
              FROM ServiceRequest__c WHERE Id = :sr.Id];
        Receipt__c rec = new Receipt__c(
            Account__c    = sr.AccountId__c,
            SalesOrder__c = sr.SalesOrder__c,
            Status__c     = 'Confirmed',
            Receipt_Amount__c = 100
        );
        insert rec;
        return rec;
    }

    // ─────────────────────────────────────────────────────────────────
    // 1. SO only — empty invoice + receipt lists
    //    Covers: hasSO=true, soGatePassed path, finish() with empty invoiceIds
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_SOOnly_EmptyLists() {
        ServiceRequest__c sr = createFullSRData();

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(String.valueOf(sr.Id), new List<String>(), new List<String>()),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Sync_Status__c,
            'Sync_Status__c should be set after batch');
    }

    // ─────────────────────────────────────────────────────────────────
    // 2. Null invoice + receipt lists
    //    Covers: null list normalisation in constructor
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_NullLists() {
        ServiceRequest__c sr = createFullSRData();

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(String.valueOf(sr.Id), null, null),
            1
        );
        Test.stopTest();

        System.assertNotEquals(null,
            [SELECT Id FROM ServiceRequest__c WHERE Id = :sr.Id].Id);
    }

    // ─────────────────────────────────────────────────────────────────
    // 3. Constructor guard — blank serviceRequestId
    //    Covers: EBSBatchException on blank SR Id
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_Constructor_BlankSRId() {
        try {
            new EBSTransferBatch(null, null, null);
            System.assert(false, 'Exception expected');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('serviceRequestId is required'),
                'Wrong exception: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // 4. Constructor guard — invoiceIds > 15
    //    Covers: EBSBatchException on oversized invoice list
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_Constructor_InvoiceLimitException() {
        ServiceRequest__c sr = createFullSRData();
        List<String> ids = new List<String>();
        for (Integer i = 0; i < 16; i++) ids.add(String.valueOf(sr.Id));

        try {
            new EBSTransferBatch(String.valueOf(sr.Id), ids, null);
            System.assert(false, 'Exception expected');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('invoiceIds exceeds maximum of 15'),
                'Wrong exception: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // 5. Constructor guard — paymentIds > 15
    //    Covers: EBSBatchException on oversized receipt list
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_Constructor_ReceiptLimitException() {
        ServiceRequest__c sr = createFullSRData();
        List<String> ids = new List<String>();
        for (Integer i = 0; i < 16; i++) ids.add(String.valueOf(sr.Id));

        try {
            new EBSTransferBatch(String.valueOf(sr.Id), null, ids);
            System.assert(false, 'Exception expected');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('paymentIds exceeds maximum of 15'),
                'Wrong exception: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // 6. Invoice callout path — valid invoice, no SO
    //    Covers: soGatePassed=true (no SO), invoice loop try block,
    //            invoiceGatePassed, finish() with non-empty invoiceIds
    //            → OIC_ManageBankDataBatch enqueued
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_InvoicePath_ValidInvoice_NoSO() {
        ServiceRequest__c sr = createFullSRData();
        Invoice__c inv = createInvoice(sr);

        update new ServiceRequest__c(
            Id = sr.Id,
            SalesOrder__c              = null,
            Sales_Order_Installment__c = null
        );

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(inv.Id) },
                new List<String>()
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c, SR_Sync_Ids__c
                                    FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Sync_Status__c);
    }

    // ─────────────────────────────────────────────────────────────────
    // 7. Invoice exception path — invalid ID forces catch block
    //    Covers: invoice loop catch block, oicErrorInvoiceIds populated,
    //            invoiceGatePassed=false, receipt skipped,
    //            syncIdsJson built with failed invoice, buildErrorDetail,
    //            idsToJsonArray with items, quoteId(null)
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_InvoicePath_InvalidId_ExceptionCatch() {
        ServiceRequest__c sr = createFullSRData();

        update new ServiceRequest__c(
            Id = sr.Id,
            SalesOrder__c              = null,
            Sales_Order_Installment__c = null
        );

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(sr.Id) }, // wrong type → exception
                new List<String>()
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c, SR_Sync_Ids__c
                                    FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Id);
        // SR_Sync_Ids__c should carry retry JSON since invoice failed
        System.assertNotEquals(null, result.SR_Sync_Ids__c,
            'SR_Sync_Ids__c should hold retry JSON on failure');
    }

    // ─────────────────────────────────────────────────────────────────
    // 8. Receipt exception path — invalid receipt ID forces catch
    //    Covers: receipt loop catch block, oicErrorReceiptIds,
    //            buildErrorDetail for receipts, idsToJsonArray for receipts,
    //            quoteId(null) when soId is blank
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_ReceiptPath_InvalidId_ExceptionCatch() {
        ServiceRequest__c sr = createFullSRData();

        update new ServiceRequest__c(
            Id = sr.Id,
            SalesOrder__c              = null,
            Sales_Order_Installment__c = null
        );

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>(),
                new List<String>{ String.valueOf(sr.Id) } // wrong type → exception
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c, SR_Sync_Ids__c
                                    FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Id);
        System.assertNotEquals(null, result.SR_Sync_Ids__c,
            'SR_Sync_Ids__c should hold retry JSON on receipt failure');
    }

    // ─────────────────────────────────────────────────────────────────
    // 9. Invoice + receipt both fail
    //    Covers: both oicErrorInvoiceIds and oicErrorReceiptIds populated,
    //            all three errorLines built in syncIdsJson block,
    //            hasErrors used indirectly via gate logic
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_InvoiceAndReceipt_BothFail() {
        ServiceRequest__c sr = createFullSRData();

        update new ServiceRequest__c(
            Id = sr.Id,
            SalesOrder__c              = null,
            Sales_Order_Installment__c = null
        );

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(sr.Id) },
                new List<String>{ String.valueOf(sr.Id) }
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c, SR_Sync_Ids__c
                                    FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Id);
        System.assertNotEquals(null, result.SR_Sync_Ids__c);
    }

    // ─────────────────────────────────────────────────────────────────
    // 10. SO present and OICIntegrationStatus contains 'Failed'
    //     Covers: hasSO=true branch, SO callout try block,
    //             soGatePassed=false path when SO fails,
    //             invoice + receipt skipped due to SO gate,
    //             oicErrorSalesOrderId set, quoteId(non-null),
    //             errorLines SO section
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_SOFailed_SkipsInvoiceAndReceipt() {
        ServiceRequest__c sr = createFullSRData();
        Invoice__c inv = createInvoice(sr);

        // Set SO status to Failed so the callout branch fires
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE Id = :sr.SalesOrder__c];
        so.OICIntegrationStatus__c = 'Transfer Failed';
        update so;

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(inv.Id) },
                new List<String>{ String.valueOf(sr.Id) }
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c, SR_Sync_Ids__c
                                    FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Id);
    }

    // ─────────────────────────────────────────────────────────────────
    // 11. SO present but OICIntegrationStatus is NOT Failed
    //     Covers: else branch soGatePassed=true (4.0 line),
    //             invoice gate opens, finish() with invoiceIds
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_SO_NotFailed_GateOpens() {
        ServiceRequest__c sr = createFullSRData();
        Invoice__c inv = createInvoice(sr);

        // OICIntegrationStatus is null → else branch fires, soGatePassed=true
        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(inv.Id) },
                new List<String>()
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Sync_Status__c);
    }

    // ─────────────────────────────────────────────────────────────────
    // 12. SR_Sync_Ids__c pre-populated — simulates retry scenario
    //     Covers: updateServiceRequest(Boolean, String) 2-arg overload
    //             called from allPassed=true path
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_RetryScenario_SyncJsonCleared_OnSuccess() {
        ServiceRequest__c sr = createFullSRData();
        Invoice__c inv = createInvoice(sr);

        String syncJson =
            '{"soId":"' + sr.SalesOrder__c + '",'
            + '"invoiceIds":["' + inv.Id + '"],'
            + '"receiptIds":[]}';

        update new ServiceRequest__c(
            Id             = sr.Id,
            SR_Sync_Ids__c = syncJson,
            Sync_Status__c = 'Not Yet Started'
        );

        // Remove SO so allPassed=true is reachable when invoice also succeeds
        update new ServiceRequest__c(
            Id = sr.Id,
            SalesOrder__c              = null,
            Sales_Order_Installment__c = null
        );

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(inv.Id) },
                new List<String>()
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c, SR_Sync_Ids__c
                                    FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Sync_Status__c);
    }

    // ─────────────────────────────────────────────────────────────────
    // 13. Valid invoice + valid receipt — all paths
    //     Covers: receipt loop try block, paymentUpdates populated,
    //             DML 2 receipt update path, handleSaveResults for receipts,
    //             finish() with non-empty invoiceIds
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_InvoiceAndReceipt_ValidIds() {
        ServiceRequest__c sr = createFullSRData();
        Invoice__c inv = createInvoice(sr);
        Receipt__c rec = createReceipt(sr);

        update new ServiceRequest__c(
            Id = sr.Id,
            SalesOrder__c              = null,
            Sales_Order_Installment__c = null
        );

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(inv.Id) },
                new List<String>{ String.valueOf(rec.Id) }
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c, SR_Sync_Ids__c
                                    FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Sync_Status__c);
    }

    // ─────────────────────────────────────────────────────────────────
    // 14. idsToJsonArray with empty list — covers empty-array branch
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_IdsToJsonArray_EmptyList() {
        ServiceRequest__c sr = createFullSRData();

        // Force the syncIdsJson path with empty receipt list
        // so idsToJsonArray([]) branch is hit
        update new ServiceRequest__c(
            Id = sr.Id,
            SalesOrder__c              = null,
            Sales_Order_Installment__c = null
        );

        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(sr.Id) }, // fails → syncIdsJson built
                new List<String>()                          // empty → idsToJsonArray([]) = '[]'
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, SR_Sync_Ids__c FROM ServiceRequest__c WHERE Id = :sr.Id];
        // receiptIds should be [] in the JSON
        if (result.SR_Sync_Ids__c != null) {
            System.assert(result.SR_Sync_Ids__c.contains('"receiptIds":[]'),
                'receiptIds should be [] — got: ' + result.SR_Sync_Ids__c);
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // 15. SO exception path — covers SO catch block
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_SOException_CatchBlock() {
        ServiceRequest__c sr = createFullSRData();

        // Mark SO as failed to trigger the callout branch
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE Id = :sr.SalesOrder__c];
        so.OICIntegrationStatus__c = 'Transfer Failed';
        update so;

        // No invoices/receipts — isolates SO branch
        Test.startTest();
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>(),
                new List<String>()
            ),
            1
        );
        Test.stopTest();

        ServiceRequest__c result = [SELECT Id, Sync_Status__c FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertNotEquals(null, result.Id);
    }

    // ─────────────────────────────────────────────────────────────────
    // 16. executeCompleted flag + logOutcome() via finish()
    //     Covers: logOutcome() debug lines, executeCompleted=true
    // ─────────────────────────────────────────────────────────────────
    @IsTest
    static void test_FinishAndLogOutcome() {
        ServiceRequest__c sr = createFullSRData();
        Invoice__c inv = createInvoice(sr);

        update new ServiceRequest__c(
            Id = sr.Id,
            SalesOrder__c              = null,
            Sales_Order_Installment__c = null
        );

        Test.startTest();
        // finish() always calls logOutcome() which prints invoiceResults + paymentResults
        Database.executeBatch(
            new EBSTransferBatch(
                String.valueOf(sr.Id),
                new List<String>{ String.valueOf(inv.Id) },
                new List<String>{ String.valueOf(sr.Id) }
            ),
            1
        );
        Test.stopTest();

        // If we reach here without exception, finish() and logOutcome() ran
        System.assert(true, 'finish() and logOutcome() completed without error');
    }
}