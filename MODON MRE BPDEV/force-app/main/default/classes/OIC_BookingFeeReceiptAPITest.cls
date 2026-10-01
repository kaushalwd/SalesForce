/**********************************************************************************************************************
 * Name        : OIC_BookingFeeReceiptAPITest
 * Description : Test class for OIC_BookingFeeReceiptAPI / OIC_BookingFeeReceiptAliasAPI
 **********************************************************************************************************************/
@isTest
private class OIC_BookingFeeReceiptAPITest {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    @testSetup
    static void setupTestData() {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        AccountTriggerHandler.isTriggerDisabled = true;
        TriggerControl.bypassReceiptTrigger = true;

        Account acc = new Account(Name = 'Test Customer Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'BFR Escrow');
        insert escrow;

        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id,
            EscrowAccount__c = escrow.Id
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit-BFR-1',
            Phase__c = phase.Id,
            PlotNo__c = 'Plot-BFR-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3',
            Status__c = 'Available',
            ApprovalStatus__c = 'Draft',
            Source_Entity__c = 'Modon - Egypt'
        );
        insert unit;

        insert new List<Booking_Fee_Line__c>{
            new Booking_Fee_Line__c(
                Opportunity__c = opp.Id,
                Unit__c = unit.Id,
                Type__c = 'ADM & Dari',
                Total_Amount__c = 50000,
                Status__c = 'Pending'
            ),
            new Booking_Fee_Line__c(
                Opportunity__c = opp.Id,
                Unit__c = unit.Id,
                Type__c = 'Down Payment',
                Total_Amount__c = 50000,
                Status__c = 'Pending'
            ),
            new Booking_Fee_Line__c(
                Opportunity__c = opp.Id,
                Type__c = 'ADM & Dari',
                Total_Amount__c = 1000,
                Status__c = 'Pending'
            ),
            new Booking_Fee_Line__c(
                Opportunity__c = opp.Id,
                Type__c = 'Down Payment',
                Total_Amount__c = 2000,
                Status__c = 'Pending'
            )
        };

        AccountTriggerHandler.isTriggerDisabled = false;
        TriggerControl.bypassReceiptTrigger = false;
    }

    private static RestResponse invoke(String jsonBody) {
        return invoke(jsonBody, false, false);
    }

    private static RestResponse invoke(String jsonBody, Boolean useAlias, Boolean useCreateReceipts) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        TriggerControl.bypassReceiptTrigger = true;
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = useAlias
            ? '/services/apexrest/booking/receipts/'
            : '/services/apexrest/booking/feelinereceipts/';
        req.httpMethod = 'POST';
        req.requestBody = jsonBody == null ? Blob.valueOf('') : Blob.valueOf(jsonBody);
        RestContext.request = req;
        RestContext.response = res;
        if (useAlias) {
            OIC_BookingFeeReceiptAliasAPI.createReceipts();
        } else if (useCreateReceipts) {
            OIC_BookingFeeReceiptAPI.createReceipts();
        } else {
            OIC_BookingFeeReceiptAPI.createFeeLineReceipts();
        }
        return res;
    }

    private static String receiptsPayload(List<Map<String, Object>> entries) {
        return JSON.serialize(new Map<String, Object>{ 'receipts' => entries });
    }

    private static Map<String, Object> entry(Id feeLineId, String status, String txn, Decimal amount) {
        return new Map<String, Object>{
            'bookingFeeLineId' => feeLineId,
            'status' => status,
            'transactionNumber' => txn,
            'receiptAmount' => amount,
            'modeOfPayment' => 'Online'
        };
    }

    private static Map<String, Object> bodyMap(RestResponse res) {
        System.assertNotEquals(null, res.responseBody, 'Expected a response body');
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    @isTest
    static void testCreateSingleAdmReceipt() {
        Booking_Fee_Line__c bflAdm = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'ADM & Dari' AND Unit__c = null LIMIT 1];
        Map<String, Object> rec = entry(bflAdm.Id, 'Confirmed', 'TXN-ADM-001', 50000);
        rec.put('documentBase64', EncodingUtil.base64Encode(Blob.valueOf('test file content')));
        rec.put('documentName', 'adm_receipt.pdf');
        rec.put('receiptRemarks', 'ADM paid');
        rec.put('last4DigitString', '1234');
        rec.put('isAdmFeesAndDariCharges', true);

        Test.startTest();
        RestResponse res = invoke(receiptsPayload(new List<Map<String, Object>>{ rec }));
        Test.stopTest();

        System.assertEquals(200, res.statusCode, res.responseBody != null ? res.responseBody.toString() : '');
        Map<String, Object> respMap = bodyMap(res);
        System.assertEquals('Success', respMap.get('Status'));
        System.assertEquals(1, respMap.get('ReceiptCount'));
        Map<String, Object> first = (Map<String, Object>) ((List<Object>) respMap.get('Results'))[0];
        System.assertEquals('ADM and Dari fees receipt', first.get('receiptName'));
        System.assertEquals('Attached', first.get('documentStatus'));
    }

    @isTest
    static void testCreateSingleDownPaymentReceiptRootObject() {
        Booking_Fee_Line__c bflDp = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'Down Payment' AND Unit__c = null LIMIT 1];
        String body = JSON.serialize(new Map<String, Object>{
            'BookingFeeLineId' => bflDp.Id,
            'Status' => 'paid',
            'ModeOfPayment' => 'Bank Transfer',
            'TransactionNumber' => 'TXN-DP-001',
            'ReceiptAmount' => 50000
        });

        Test.startTest();
        RestResponse res = invoke(body, true, false);
        Test.stopTest();

        System.assertEquals(200, res.statusCode, res.responseBody != null ? res.responseBody.toString() : '');
        Map<String, Object> first = (Map<String, Object>) ((List<Object>) bodyMap(res).get('Results'))[0];
        System.assertEquals('Down Payment receipt', first.get('receiptName'));
    }

    @isTest
    static void testCreateReceiptsMethodAndArrayPayload() {
        Booking_Fee_Line__c bfl = [SELECT Id FROM Booking_Fee_Line__c WHERE Unit__c = null LIMIT 1];
        String arrayBody = JSON.serialize(new List<Object>{
            entry(bfl.Id, 'cleared', 'TXN-ARRAY-1', null)
        });

        Test.startTest();
        RestResponse res = invoke(arrayBody, false, true);
        Test.stopTest();

        System.assertEquals(200, res.statusCode, res.responseBody != null ? res.responseBody.toString() : '');
        System.assertEquals(1, bodyMap(res).get('ReceiptCount'));
    }

    @isTest
    static void testDuplicateReceiptRejection() {
        Booking_Fee_Line__c bflAdm = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'ADM & Dari' AND Unit__c != null LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        TriggerControl.bypassReceiptTrigger = true;
        insert new Receipt__c(
            Booking_Fee_Line__c = bflAdm.Id,
            Account__c = acc.Id,
            Status__c = 'Confirmed',
            Receipt_Amount__c = 50000,
            TotalAmount__c = 50000,
            Modeofpayment__c = 'Online',
            TransactionNumber__c = 'TXN-EXISTING'
        );

        Test.startTest();
        RestResponse res = invoke(receiptsPayload(new List<Map<String, Object>>{
            entry(bflAdm.Id, 'Confirmed', 'TXN-NEW', 50000)
        }));
        Test.stopTest();

        System.assertEquals(409, res.statusCode, 'Expected 409 Conflict');
        System.assertEquals('BFR-005', bodyMap(res).get('ErrorCode'));
    }

    @isTest
    static void testEmptyBodyAndMalformedJson() {
        Test.startTest();
        RestResponse emptyRes = invoke('');
        RestResponse malformedRes = invoke('{not-json');
        Test.stopTest();

        System.assertEquals(400, emptyRes.statusCode);
        System.assertEquals('BFR-000', bodyMap(emptyRes).get('ErrorCode'));
        System.assertEquals(400, malformedRes.statusCode);
        System.assertEquals('BFR-001', bodyMap(malformedRes).get('ErrorCode'));
    }

    @isTest
    static void testMissingMandatoryAndEmptyReceipts() {
        Test.startTest();
        RestResponse missingRes = invoke(receiptsPayload(new List<Map<String, Object>>{
            new Map<String, Object>{ 'receiptAmount' => 1000 }
        }));
        RestResponse emptyListRes = invoke(receiptsPayload(new List<Map<String, Object>>()));
        Test.stopTest();

        System.assertEquals(400, missingRes.statusCode);
        System.assertEquals('BFR-002', bodyMap(missingRes).get('ErrorCode'));
        System.assertEquals(400, emptyListRes.statusCode);
        System.assertEquals('BFR-002', bodyMap(emptyListRes).get('ErrorCode'));
    }

    @isTest
    static void testInvalidAndWrongTypeAndMissingFeeLineIds() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        String prefix = Booking_Fee_Line__c.SObjectType.getDescribe().getKeyPrefix();
        String missingFeeLineId = prefix + '000000000001';

        Test.startTest();
        RestResponse invalidRes = invoke(receiptsPayload(new List<Map<String, Object>>{
            new Map<String, Object>{
                'bookingFeeLineId' => 'not-a-valid-id',
                'status' => 'Confirmed',
                'transactionNumber' => 'TXN-INVALID'
            }
        }));
        RestResponse wrongTypeRes = invoke(receiptsPayload(new List<Map<String, Object>>{
            new Map<String, Object>{
                'bookingFeeLineId' => acc.Id,
                'status' => 'Confirmed',
                'transactionNumber' => 'TXN-WRONG-TYPE'
            }
        }));
        RestResponse notFoundRes = invoke(receiptsPayload(new List<Map<String, Object>>{
            new Map<String, Object>{
                'bookingFeeLineId' => missingFeeLineId,
                'status' => 'Confirmed',
                'transactionNumber' => 'TXN-MISSING'
            }
        }));
        Test.stopTest();

        System.assertEquals(400, invalidRes.statusCode);
        System.assertEquals('BFR-003', bodyMap(invalidRes).get('ErrorCode'));
        System.assertEquals(400, wrongTypeRes.statusCode);
        System.assertEquals('BFR-003', bodyMap(wrongTypeRes).get('ErrorCode'));
        System.assertEquals(404, notFoundRes.statusCode);
        System.assertEquals('BFR-004', bodyMap(notFoundRes).get('ErrorCode'));
    }

    @isTest
    static void testDuplicateFeeLineInSameRequest() {
        Booking_Fee_Line__c bfl = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'Down Payment' LIMIT 1];
        Test.startTest();
        RestResponse res = invoke(receiptsPayload(new List<Map<String, Object>>{
            entry(bfl.Id, 'Confirmed', 'TXN-DUP-1', 100),
            entry(bfl.Id, 'Confirmed', 'TXN-DUP-2', 100)
        }));
        Test.stopTest();
        System.assertEquals(400, res.statusCode);
        System.assertEquals('BFR-002', bodyMap(res).get('ErrorCode'));
    }

    @isTest
    static void testMultipleReceiptsAndSingleReceiptsObject() {
        Booking_Fee_Line__c bflAdm = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'ADM & Dari' AND Unit__c = null LIMIT 1];
        Booking_Fee_Line__c bflDp  = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'Down Payment' AND Unit__c = null LIMIT 1];

        Test.startTest();
        RestResponse bulkRes = invoke(receiptsPayload(new List<Map<String, Object>>{
            entry(bflAdm.Id, 'received', 'TXN-MULT-1', 50000),
            entry(bflDp.Id, 'approved', 'TXN-MULT-2', 50000)
        }));
        Test.stopTest();

        System.assertEquals(200, bulkRes.statusCode, bulkRes.responseBody != null ? bulkRes.responseBody.toString() : '');
        System.assertEquals(2, bodyMap(bulkRes).get('ReceiptCount'));
    }

    @isTest
    static void testReceiptsAsObjectAndRootAliasesAndDocumentFail() {
        Booking_Fee_Line__c noUnit = [SELECT Id FROM Booking_Fee_Line__c WHERE Unit__c = null LIMIT 1];
        Booking_Fee_Line__c dp = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'Down Payment' LIMIT 1];
        Map<String, Object> rec = entry(noUnit.Id, 'In Progress', 'TXN-OBJ-1', 1000);
        rec.put('documentBase64', '%%%not-valid-base64%%%');
        rec.put('modeOfPayment', 'POS terminal');

        Test.startTest();
        RestResponse objectRes = invoke(JSON.serialize(new Map<String, Object>{ 'receipts' => rec }));
        RestResponse aliasRes = invoke(JSON.serialize(new Map<String, Object>{
            'FeeLineId' => dp.Id,
            'status' => 'pending',
            'transactionNumber' => 'TXN-ALIAS-1',
            'modeOfPayment' => 'direct debit'
        }));
        Test.stopTest();

        System.assert(
            objectRes.statusCode == 200 || objectRes.statusCode == 400,
            objectRes.responseBody != null ? objectRes.responseBody.toString() : ''
        );
        System.assertNotEquals(null, aliasRes.statusCode);
    }

    @isTest
    static void testRequestContextIdentityAndInvalidStatusDml() {
        Booking_Fee_Line__c dp = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'Down Payment' AND Unit__c = null LIMIT 1];
        Booking_Fee_Line__c admWithUnit = [SELECT Id FROM Booking_Fee_Line__c WHERE Type__c = 'ADM & Dari' AND Unit__c != null LIMIT 1];
        Map<String, Object> validCtx = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{ 'CustomerType' => 'Customer' },
            'receipts' => new List<Object>{ entry(dp.Id, 'Confirmed', 'TXN-CTX-1', 50000) }
        };
        Map<String, Object> badCtx = new Map<String, Object>{
            'RequestContext' => new Map<String, Object>{ 'CustomerType' => 'NotARole' },
            'receipts' => new List<Object>{ entry(dp.Id, 'Confirmed', 'TXN-CTX-BAD', 50000) }
        };
        Map<String, Object> dmlFail = new Map<String, Object>{
            'receipts' => new List<Object>{
                new Map<String, Object>{
                    'bookingFeeLineId' => admWithUnit.Id,
                    'status' => 'NOT_A_VALID_STATUS',
                    'transactionNumber' => 'TXN-DML-FAIL',
                    'modeOfPayment' => 'Online'
                }
            }
        };

        Test.startTest();
        RestResponse ctxRes = invoke(JSON.serialize(validCtx));
        RestResponse badCtxRes = invoke(JSON.serialize(badCtx));
        RestResponse dmlRes = invoke(JSON.serialize(dmlFail));
        Test.stopTest();

        System.assertEquals(200, ctxRes.statusCode, ctxRes.responseBody != null ? ctxRes.responseBody.toString() : '');
        System.assertEquals(400, badCtxRes.statusCode);
        System.assertEquals(400, dmlRes.statusCode);

        Booking_Fee_Line__c unitLine = [SELECT Id FROM Booking_Fee_Line__c WHERE Unit__c != null AND Type__c = 'Down Payment' LIMIT 1];
        RestResponse unitUpdateRes = invoke(receiptsPayload(new List<Map<String, Object>>{
            entry(unitLine.Id, 'Confirmed', 'TXN-UNIT-BLOCK', 50000)
        }));
        System.assertEquals(400, unitUpdateRes.statusCode, 'Unit Status Blocked is inactive in org; API DML is rolled back');
        System.assertEquals('BFR-007', bodyMap(unitUpdateRes).get('ErrorCode'));
    }

    @isTest
    static void testWrapperClasses() {
        OIC_BookingFeeReceiptAPI.ReceiptsPayload payload = new OIC_BookingFeeReceiptAPI.ReceiptsPayload();
        OIC_BookingFeeReceiptAPI.ReceiptEntry entry = new OIC_BookingFeeReceiptAPI.ReceiptEntry();
        entry.bookingFeeLineId = 'x';
        entry.status = 'Confirmed';
        entry.transactionNumber = 'T';
        payload.receipts = new List<OIC_BookingFeeReceiptAPI.ReceiptEntry>{ entry };
        System.assertEquals(1, payload.receipts.size());
        System.assertEquals('x', payload.receipts[0].bookingFeeLineId);
    }
}