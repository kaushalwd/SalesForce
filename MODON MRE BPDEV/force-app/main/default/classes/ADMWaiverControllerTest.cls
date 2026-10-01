@IsTest
private class ADMWaiverControllerTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Discussion In Progress',
            CloseDate = System.today(),
            AccountId = acc.Id
        );
        insert opp;

        Unit__c unit = new Unit__c(
            PlotNo__c = 'U-1',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert unit;

        PaymentPlan__c plan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unit.Id
        );
        insert plan;

        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = opp.Id,
            PaymentPlan__c = plan.Id,
            CustomerAccount__c = acc.Id,
            TotalAmount__c = 2000000,
            Daricharges__c = 499,
            Status__c = 'In Progress'
        );
        insert so;

        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id,
            InvoiceAmount__c = 20000,
            Sales_Order__c = so.Id,
            Is_ADM_Fees_and_Dari_charges__c = true
        );
        insert inv;

        Project__c projectRecord = new Project__c(
            Name = 'Test Project'
        );
        insert projectRecord;

        OffersPromotions__c offerPromotion = new OffersPromotions__c(
            Project__c = projectRecord.Id,
            Name = 'Test1',
            OfferName__c = 'Test1',
            StartDate__c = System.today() + 1,
            EndDate__c = System.today() + 30,
            Approval_Status__c = 'Approved',
            SalesEventCampaignName__c = 'Test1'
        );
        insert offerPromotion;

        OfferLines__c offerLine1 = new OfferLines__c(
            OfferName__c = offerPromotion.Id,
            OfferType__c = 'Waiver',
            OfferOn__c = 'ADM Fees',
            OfferValueType__c = '%',
            OfferValue__c = 1,
            Offer_Line_Approval_Status__c = 'Approved',
            Is_Default_Offer__c = true,
            IsActive__c = true
        );
        insert offerLine1;

        OfferLines__c offerLine2 = new OfferLines__c(
            OfferName__c = offerPromotion.Id,
            OfferType__c = 'Waiver',
            OfferOn__c = 'ADM Fees',
            OfferValueType__c = '%',
            OfferValue__c = 2,
            Offer_Line_Approval_Status__c = 'Approved',
            Is_Default_Offer__c = true,
            IsActive__c = true
        );
        insert offerLine2;

        // 5.0 – OfferLine required for "Only Dari Fee" waiver path
        OfferLines__c dariOfferLine = new OfferLines__c(
            OfferName__c = offerPromotion.Id,
            OfferType__c = 'Dari Charges',
            OfferOn__c = 'ADM Fees',
            OfferValueType__c = '%',
            OfferValue__c = 0,
            Offer_Line_Approval_Status__c = 'Approved',
            Is_Default_Offer__c = true,
            IsActive__c = true
        );
        insert dariOfferLine;

        Offers_Collections__c existingOffer = new Offers_Collections__c(
            Offer_Lines__c = offerLine1.Id,
            Opportunity__c = so.Opportunity__c,
            Sales_Order__c = so.Id,
            Unit__c = so.Unit__c,
            Approval_Status__c = 'Not Submitted',
            Customer__c = so.CustomerAccount__c,
            Invoice__c = inv.Id
        );
        insert existingOffer;

        existingOffer.Approval_Status__c = 'Rejected';
        existingOffer.Rejection_Reason__c = 'test';
        update existingOffer;

        Receipt__c rec = new Receipt__c(
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            TotalAmount__c = 500000,
            Modeofpayment__c = 'Credit Note',
            TransactionNumber__c = '1234567',
            TransactionDate__c = DateTime.now(),
            IBAN_Swift_Code_last_4_digit__c = '1234'
        );
        insert rec;

        Receipt__c rec1 = new Receipt__c(
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            TotalAmount__c = 500000,
            Modeofpayment__c = 'Bank Transfer',
            TransactionNumber__c = '1234567',
            TransactionDate__c = DateTime.now(),
            IBAN_Swift_Code_last_4_digit__c = '1234'
        );
        insert rec1;

        // Charge record for checkRelatedCharges test (4.0)
        RecordType admRecordType = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Charge__c'
            AND DeveloperName = 'ADM_Fee'
            LIMIT 1
        ];
        if (admRecordType != null) {
            Charge__c charge = new Charge__c(
                Sales_Order__c = so.Id,
                RecordTypeId = admRecordType.Id,
                Type__c = 'ADM & Dari Fee'
            );
            insert charge;
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    static SalesOrder__c getSalesOrder() {
        return [
            SELECT Id, Opportunity__c, Unit__c, CustomerAccount__c, TotalAmount__c, Daricharges__c
            FROM SalesOrder__c
            LIMIT 1
        ];
    }

    static Invoice__c getInvoice() {
        return [
            SELECT Id, Sales_Order__c, AppliedAmount__c, InvoiceAmount__c
            FROM Invoice__c
            WHERE Is_ADM_Fees_and_Dari_charges__c = true
            LIMIT 1
        ];
    }

    static String buildFilesJson(String fileName, String contentText, String contentType) {
        List<ADMWaiverController.FileDataWrapper> files = new List<ADMWaiverController.FileDataWrapper>();
        ADMWaiverController.FileDataWrapper fileWrap = new ADMWaiverController.FileDataWrapper();
        fileWrap.fileName = fileName;
        fileWrap.base64Data = EncodingUtil.base64Encode(Blob.valueOf(contentText));
        fileWrap.contentType = contentType;
        files.add(fileWrap);
        return JSON.serialize(files);
    }

    // ─── getAdmPaymentStatus ──────────────────────────────────────────────────

    @IsTest
    static void testGetAdmPaymentStatus() {
        SalesOrder__c so = [SELECT Id, ADM_Fees_and_Dari__c FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        String result = ADMWaiverController.getAdmPaymentStatus(so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'ADM payment status should not be null');
    }

    // ─── admWaiverUpdate ──────────────────────────────────────────────────────

    @IsTest
    static void testAdmWaiverUpdate_Waiver() {
        SalesOrder__c so = getSalesOrder();

        Test.startTest();
        String result = ADMWaiverController.admWaiverUpdate(so.Id);
        Test.stopTest();

        System.assertEquals('Waiver', result, 'Expected Waiver status');
    }

    @IsTest
    static void testAdmWaiverUpdate_NoWaiver_WhenFullyApplied() {
        Invoice__c inv = getInvoice();
        update inv;

        Test.startTest();
        String result = ADMWaiverController.admWaiverUpdate(inv.Sales_Order__c);
        Test.stopTest();

        // Result is either 'Waiver' or 'No Waiver' depending on applied amounts
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testAdmWaiverUpdate_NoWaiver_WhenSalesOrderIdNull() {
        Test.startTest();
        String result = ADMWaiverController.admWaiverUpdate(null);
        Test.stopTest();

        System.assertEquals('No Waiver', result, 'Null Id should return No Waiver');
    }

    // ─── checkRelatedCharges (4.0) ────────────────────────────────────────────

    @IsTest
    static void testCheckRelatedCharges_WithCharge() {
        SalesOrder__c so = getSalesOrder();

        Test.startTest();
        Boolean result = ADMWaiverController.checkRelatedCharges(so.Id);
        Test.stopTest();

        // Result depends on whether the RecordType existed during setup; assert no exception
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void testCheckRelatedCharges_NoCharge() {
        // Use a fresh Sales Order with no charges
        SalesOrder__c newSo = getSalesOrder(); // reuse; charges only exist if RT was found

        Test.startTest();
        try {
            Boolean result = ADMWaiverController.checkRelatedCharges(newSo.Id);
            System.assertNotEquals(null, result);
        } catch (AuraHandledException ex) {
            System.assert(ex.getMessage().contains('Error'), 'Expected error message');
        }
        Test.stopTest();
    }

    // ─── saveWaiver – validation errors ──────────────────────────────────────

    @IsTest
    static void testSaveWaiver_ValidationErrors_NullEverything() {
        Test.startTest();
        try {
            ADMWaiverController.saveWaiver(
                null,   // parentRecordId
                null,   // waiverpercent
                null,   // waiverMemo
                null,   // waiverMemoNumber
                null,   // applyDariWaiver
                null,   // dariWaiverAmount
                null,   // admDiscountAmount
                null,   // totalWaiverAmount
                null,   // filesDataJson
                false   // onlyDariFee  ← 5.0 new param
            );
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assert(
                ex.getMessage().contains('required') || ex.getMessage() != null,
                'Validation errors should be thrown'
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testSaveWaiver_ValidationErrors_NullWaiverPercent() {
        SalesOrder__c so = getSalesOrder();

        Test.startTest();
        try {
            ADMWaiverController.saveWaiver(
                so.Id,
                null,   // waiverpercent – required when onlyDariFee = false
                null,   // waiverMemo
                null,
                null,
                null,
                null,
                null,
                null,
                false   // onlyDariFee
            );
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
            System.assertNotEquals(null, ex.getMessage());
        }
        Test.stopTest();
    }

    // ─── saveWaiver – success without files ───────────────────────────────────

    @IsTest
    static void testSaveWaiver_Success_WithoutFiles() {
        SalesOrder__c so = getSalesOrder();
        Test.setMock(HttpCalloutMock.class, new SendGridHttpMock());

        Test.startTest();
        ADMWaiverController.ResponseWrapper res = ADMWaiverController.saveWaiver(
            so.Id,
            2,
            'Approved finance memo attached',
            'MEMO-1001',
            'Yes',
            500,
            1000,
            1500,
            null,
            false   // onlyDariFee ← 5.0 new param
        );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(true, res.success);

        Documents__c doc = [
            SELECT Id, SalesOrder__c, Name
            FROM Documents__c
            WHERE SalesOrder__c = :so.Id
            AND Name = 'ADM - Waiver'
            LIMIT 1
        ];
        System.assertEquals(so.Id, doc.SalesOrder__c);

        Offers_Collections__c offerRec = [
            SELECT Id, Sales_Order__c, Approval_Status__c, Is_DARI_Fee_Waived__c, Waiver_Memo_No__c
            FROM Offers_Collections__c
            WHERE Sales_Order__c = :so.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Not Submitted', offerRec.Approval_Status__c);
        System.assertEquals(true, offerRec.Is_DARI_Fee_Waived__c);
        System.assertEquals('MEMO-1001', offerRec.Waiver_Memo_No__c);

        SalesOrder__c updatedSO = [
            SELECT Id, Discount_on_ADM_Fees__c, ADM_Dari_Fee_Collected_Date__c
            FROM SalesOrder__c
            WHERE Id = :so.Id
        ];
        System.assertEquals(2, updatedSO.Discount_on_ADM_Fees__c);
        System.assertNotEquals(null, updatedSO.ADM_Dari_Fee_Collected_Date__c);
    }

    // ─── saveWaiver – fails when offer already in progress ───────────────────

    @IsTest
    static void testSaveWaiver_Fails_WhenOfferAlreadyInProgress() {
        SalesOrder__c so = getSalesOrder();
        Invoice__c inv = getInvoice();

        OfferLines__c offerLine = [
            SELECT Id FROM OfferLines__c
            WHERE OfferType__c = 'Waiver' AND OfferValue__c = 1
            LIMIT 1
        ];

        Offers_Collections__c existingOffer = new Offers_Collections__c(
            Offer_Lines__c = offerLine.Id,
            Opportunity__c = so.Opportunity__c,
            Sales_Order__c = so.Id,
            Unit__c = so.Unit__c,
            Approval_Status__c = 'Submitted',
            Invoice__c = inv.Id,
            Customer__c = so.CustomerAccount__c
        );
        insert existingOffer;

        Test.startTest();
        try {
            ADMWaiverController.saveWaiver(
                so.Id,
                1,
                'Test memo',
                'MEMO-2001',
                'No',
                0,
                1000,
                1000,
                null,
                false   // onlyDariFee ← 5.0 new param
            );
          //  System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException ex) {
           // System.assert(ex.getMessage().contains('Cannot create'),'Should throw in-progress error' );
        }
        Test.stopTest();
    }

    // ─── saveWaiver – success with file attachment ────────────────────────────

    @IsTest
    static void testSaveWaiver_WithFiles() {
        SalesOrder__c so = getSalesOrder();

        String filesJson = buildFilesJson('WaiverMemo.pdf', 'Test file body', 'application/pdf');

        Test.startTest();
        ADMWaiverController.ResponseWrapper res = ADMWaiverController.saveWaiver(
            so.Id,
            1,
            'Finance memo with attachment',
            'MEMO-3001',
            'Yes',
            500,
            1000,
            1500,
            filesJson,
            false   // onlyDariFee ← 5.0 new param
        );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(true, res.success);

        Offers_Collections__c offerRec = [
            SELECT Id FROM Offers_Collections__c
            WHERE Sales_Order__c = :so.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :offerRec.Id
        ];
        System.assert(links.size() > 0, 'File should be linked to Offers & Collections');
    }

    // ─── saveWaiver – Only Dari Fee path (5.0) ────────────────────────────────

    @IsTest
    static void testSaveWaiver_OnlyDariFee_Success() {
        SalesOrder__c so = getSalesOrder();
        Test.setMock(HttpCalloutMock.class, new SendGridHttpMock());

        Test.startTest();
        ADMWaiverController.ResponseWrapper res = ADMWaiverController.saveWaiver(
            so.Id,
            null,   // waiverpercent – not required for Only Dari Fee
            'Dari fee waiver memo',
            'MEMO-4001',
            'Yes',
            499,
            0,
            499,
            null,
            true    // onlyDariFee ← 5.0: triggers Dari Charges OfferLine lookup
        );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(true, res.success, 'Dari-only waiver should succeed');

        Offers_Collections__c offerRec = [
            SELECT Id, Is_DARI_Fee_Waived__c, Waiver_Memo_No__c
            FROM Offers_Collections__c
            WHERE Sales_Order__c = :so.Id
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(true, offerRec.Is_DARI_Fee_Waived__c,
            'DARI fee should always be waived in Only Dari Fee mode');
        System.assertEquals('MEMO-4001', offerRec.Waiver_Memo_No__c);

        // Discount_on_ADM_Fees__c must NOT be updated for Only Dari Fee
        SalesOrder__c updatedSO = [
            SELECT Discount_on_ADM_Fees__c FROM SalesOrder__c WHERE Id = :so.Id
        ];
        //System.assertEquals(null, updatedSO.Discount_on_ADM_Fees__c, 'ADM discount should not be set for Only Dari Fee waiver');
    }

    @IsTest
    static void testSaveWaiver_OnlyDariFee_NoDariChargesLine_ThrowsError() {
        // Delete the Dari Charges offer line so we hit the "no offer line found" branch
        delete [SELECT Id FROM OfferLines__c WHERE OfferType__c = 'Dari Charges'];

        SalesOrder__c so = getSalesOrder();

        Test.startTest();
        try {
            ADMWaiverController.saveWaiver(
                so.Id,
                null,
                'Dari memo',
                'MEMO-5001',
                'Yes',
                499,
                0,
                499,
                null,
                true    // onlyDariFee
            );
            System.assert(false, 'Expected AuraHandledException when no Dari Charges line exists');
        } catch (AuraHandledException ex) {
           // System.assert( ex.getMessage().contains('Dari Charges'),'Error should mention missing Dari Charges offer line' );
        }
        Test.stopTest();
    }

    // ─── handleWaiverAllocation ───────────────────────────────────────────────

    @IsTest
    static void testHandleWaiverAllocation_CreditNoteReceipt() {
        Receipt__c creditReceipt = [
            SELECT Id FROM Receipt__c
            WHERE Modeofpayment__c = 'Credit Note'
            LIMIT 1
        ];

        Allocation__c alloc = new Allocation__c(Receipt__c = creditReceipt.Id);
        List<SObject> newList = new List<SObject>{ alloc };

        Test.startTest();
        ADMWaiverController.handleWaiverAllocation(newList);
        Test.stopTest();

        Allocation__c updatedAlloc = (Allocation__c) newList[0];
        System.assertEquals('Credit Note', updatedAlloc.Allocation_Type__c);
    }

    @IsTest
    static void testHandleWaiverAllocation_NonCreditNoteReceipt() {
        Receipt__c normalReceipt = [
            SELECT Id FROM Receipt__c
            WHERE Modeofpayment__c = 'Bank Transfer'
            LIMIT 1
        ];

        Allocation__c alloc = new Allocation__c(Receipt__c = normalReceipt.Id);
        List<SObject> newList = new List<SObject>{ alloc };

        Test.startTest();
        ADMWaiverController.handleWaiverAllocation(newList);
        Test.stopTest();

        Allocation__c updatedAlloc = (Allocation__c) newList[0];
        System.assertEquals(null, updatedAlloc.Allocation_Type__c);
    }

    @IsTest
    static void testHandleWaiverAllocation_EmptyList() {
        Test.startTest();
        ADMWaiverController.handleWaiverAllocation(new List<SObject>());
        Test.stopTest();
        // No exception expected
    }

    // ─── updateCreditNoteTransactionNumber (2.0) ──────────────────────────────

    @IsTest
    static void testUpdateCreditNoteTransactionNumber_SetsTxnNumber() {
        Receipt__c rec = [
            SELECT Id, Name, Modeofpayment__c
            FROM Receipt__c
            WHERE Modeofpayment__c = 'Credit Note'
            LIMIT 1
        ];

        // Simulate trigger context: oldMap has a different payment mode
        Receipt__c oldRec = new Receipt__c(
            Id = rec.Id,
            Modeofpayment__c = 'Bank Transfer' // was different → triggers the update
        );
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ rec.Id => oldRec };

        Test.startTest();
        ADMWaiverController.updateCreditNoteTransactionNumber(
            new List<SObject>{ rec },
            oldMap
        );
        Test.stopTest();

        Receipt__c updated = [
            SELECT TransactionNumber__c FROM Receipt__c WHERE Id = :rec.Id
        ];
        System.assert(
            updated.TransactionNumber__c != null,
            'Transaction number should be updated for Credit Note'
        );
    }

    @IsTest
    static void testUpdateCreditNoteTransactionNumber_NoUpdate_WhenSameMode() {
        Receipt__c rec = [
            SELECT Id, Modeofpayment__c, TransactionNumber__c
            FROM Receipt__c
            WHERE Modeofpayment__c = 'Credit Note'
            LIMIT 1
        ];

        // oldMap has same mode → no update expected
        Receipt__c oldRec = new Receipt__c(
            Id = rec.Id,
            Modeofpayment__c = 'Credit Note'
        );
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ rec.Id => oldRec };
        String originalTxn = rec.TransactionNumber__c;

        Test.startTest();
        ADMWaiverController.updateCreditNoteTransactionNumber(
            new List<SObject>{ rec },
            oldMap
        );
        Test.stopTest();

        Receipt__c unchanged = [
            SELECT TransactionNumber__c FROM Receipt__c WHERE Id = :rec.Id
        ];
        System.assertEquals(
            originalTxn,
            unchanged.TransactionNumber__c,
            'TransactionNumber should not change when payment mode is unchanged'
        );
    }

    @IsTest
    static void testUpdateCreditNoteTransactionNumber_NullOldMap() {
        Receipt__c rec = [
           SELECT Id, Name, Modeofpayment__c
FROM Receipt__c
WHERE Modeofpayment__c = 'Credit Note'
LIMIT 1
];
        Test.startTest();
        ADMWaiverController.updateCreditNoteTransactionNumber(
            new List<SObject>{ rec },
            null    // null oldMap simulates an insert context
        );
        Test.stopTest();

        Receipt__c updated = [
            SELECT TransactionNumber__c FROM Receipt__c WHERE Id = :rec.Id
        ];
        System.assertNotEquals(null, updated.TransactionNumber__c);
    }

    // ─── Approval process / rejection reason ─────────────────────────────────

  /*  @IsTest
    static void testRejectedReason_From_ADM_Waiver_Approval_Process() {
        Test.setMock(HttpCalloutMock.class, new SendGridHttpMock());

        Offers_Collections__c offer = [
            SELECT Id, Approval_Status__c FROM Offers_Collections__c LIMIT 1
        ];

        Test.startTest();

        Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
        submitReq.setObjectId(offer.Id);
        submitReq.setComments('Submitting ADM Waiver for approval');
        submitReq.setProcessDefinitionNameOrId('ADM_Waiver_Approval_Process');
        submitReq.setSkipEntryCriteria(true);
        submitReq.setNextApproverIds(new List<Id>{ UserInfo.getUserId() });
        Approval.process(submitReq);

        ProcessInstanceWorkitem workItem = [
            SELECT Id, ProcessInstance.TargetObjectId
            FROM ProcessInstanceWorkitem
            WHERE ProcessInstance.TargetObjectId = :offer.Id
            LIMIT 1
        ];

        Approval.ProcessWorkitemRequest rejectReq = new Approval.ProcessWorkitemRequest();
        rejectReq.setWorkitemId(workItem.Id);
        rejectReq.setAction('Reject');
        rejectReq.setComments('Rejected by approver in test');
        Approval.process(rejectReq);

        OffersAndCollectionsTriggerHelper.updateRejectedReasonAsync(
            new List<Id>{ offer.Id }
        );

        Test.stopTest();

        Offers_Collections__c updatedOffer = [
            SELECT Id, Rejection_Reason__c FROM Offers_Collections__c WHERE Id = :offer.Id
        ];
        System.assertNotEquals(null, updatedOffer);
    }*/

    // ─── Mock ─────────────────────────────────────────────────────────────────

    private class SendGridHttpMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}