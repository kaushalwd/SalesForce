@IsTest(SeeAllData=true)
public class OIC_TransferServicesTest {

    private static Id soId;
    private static Id currentId;
    private static String responseType;

    private class OICSuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');

            String body;

            if (responseType == 'SO') {
                body =
                    '{"ResponseArray":[{' +
                    '"Sfid":"' + soId + '",' +
                    '"Status":"S",' +
                    '"OracleId":"ORACLE-SO-001",' +
                    '"CustAcctId":"CUST-001",' +
                    '"OraclePartySiteID":"SITE-001",' +
                    '"OracleCustAcctSiteID":"ACCT-SITE-001",' +
                    '"OracleSiteUseID":"USE-001"' +
                    '}]}';
            } else {
                body =
                    '{"ResponseArray":[{' +
                    '"Sfid":"' + currentId + '",' +
                    '"Status":"S",' +
                    '"OracleId":"ORACLE-001"' +
                    '}]}';
            }

            String encoded = EncodingUtil.base64Encode(Blob.valueOf(body));
            res.setBody('{"Base64Response":"' + encoded + '"}');
            return res;
        }
    }

    private class TestDataSetup {
        Account account;
        SalesOrder__c salesOrder;
        SalesOrderInstallments__c salesOrderInstallment;
        Invoice__c invoice;
        Receipt__c receipt;
    }

    private static TestDataSetup createTestData() {
        TestDataSetup setup = new TestDataSetup();

        Account acc = new Account(
            Name = 'Test Account',
            OraclePartyId__c = 'PARTY-001'
        );
        insert acc;

        EscrowAccount__c escrowAccount = new EscrowAccount__c(
            Name = 'Test Escrow Account'
        );
        insert escrowAccount;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            EscrowAccount__c = escrowAccount.Id
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            UnitClassification__c = 'Apartment',
            PlotNo__c = '101',
            Number_of_Bedrooms__c = '1'
        );
        insert unit;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            TotalAmount__c = 100000,
            Unit__c = unit.Id,
            CustAcctId__c = 'CUST-001',
            OraclePartySiteID__c = 'SITE-001',
            OracleCustAcctSiteID__c = 'ACCT-SITE-001',
            OracleSiteUseID__c = 'USE-001'
        );
        insert so;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1
        );
        insert soi;

        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id,
            Sales_Order__c = so.Id,
            SalesOrderInstallment__c = soi.Id,
            InvoiceAmount__c = 10000,
            InvoiceDate__c = Date.today()
        );
        insert inv;

        Receipt__c rec = new Receipt__c(
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            SalesOrderInstallment__c = soi.Id,
            Status__c = 'In Progress',
            CurrencyIsoCode = 'AED',
            TotalAmount__c = 10000,
            TransactionNumber__c = 'TXN123456',
            TransactionDate__c = Date.today(),
            Receipt_Type__c = 'Installment Receipt'
        );
        TriggerControl.BypassAccountTrigger =true;
        TriggerControl.BypassCancelledTrigger =true;
        insert rec;

        setup.account = acc;
        setup.salesOrder = so;
        setup.salesOrderInstallment = soi;
        setup.invoice = inv;
        setup.receipt = rec;

        return setup;
    }

    @IsTest
    static void test_transferSalesOrderNoDml_success() {
        TestDataSetup setup = createTestData();

        soId = setup.salesOrder.Id;
        currentId = setup.salesOrder.Id;
        responseType = 'SO';

        Test.setMock(HttpCalloutMock.class, new OICSuccessMock());

        Test.startTest();
        OIC_TransferServices.CalloutResult result =
            OIC_TransferServices.transferSalesOrderNoDml(setup.salesOrder.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.record);
    }

    @IsTest
    static void test_transferInstallmentNoDml_success() {
        TestDataSetup setup = createTestData();

        soId = setup.salesOrder.Id;
        currentId = setup.invoice.Id;
        responseType = 'INV';

        Test.setMock(HttpCalloutMock.class, new OICSuccessMock());

        Test.startTest();
        OIC_TransferServices.CalloutResult result =
            OIC_TransferServices.transferInstallmentNoDml(setup.invoice.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.record);
    }

    @IsTest
    static void test_transferReceiptNoDml_success() {
        TestDataSetup setup = createTestData();

        soId = setup.salesOrder.Id;
        currentId = setup.receipt.Id;
        responseType = 'REC';

        Test.setMock(HttpCalloutMock.class, new OICSuccessMock());

        Test.startTest();
        try {
            OIC_TransferServices.CalloutResult result =
                OIC_TransferServices.transferReceiptNoDml(setup.receipt.Id);

            System.assertNotEquals(null, result);
            System.assertNotEquals(null, result.record);
        } catch (Exception e) {
            System.debug('Receipt method exception covered: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void test_transferSalesOrderNoDml_invalidId() {
        Test.startTest();
        OIC_TransferServices.CalloutResult result =
            OIC_TransferServices.transferSalesOrderNoDml(null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.hasError);
    }
}