/**********************************************************************************************
 * Name           : UAEDDS_ReconciliationBatchTest
 * Description     : Covers the day-end check. The case worth having is the unmatched row - a
 *                   payment UAEDDS processed against a Modon mandate that Salesforce has no record
 *                   of requesting. That is the finding the job exists for, so it has to reach the
 *                   log rather than be quietly skipped.
 * Usage           : Test class for UAEDDS_ReconciliationBatch.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class UAEDDS_ReconciliationBatchTest {

    private class Mock implements HttpCalloutMock {
        private String body;
        private Integer code;
        private String captured;
        private Mock(String body, Integer code) {
            this.body = body;
            this.code = code;
        }
        public HttpResponse respond(HttpRequest req) {
            captured = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account person = new Account(
            FirstName = 'Recon',
            LastName = 'Tester',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'recon.tester@example.com.invalid',
            BillingCity = 'Abu Dhabi'
        );
        insert person;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'UAEDDS Recon Escrow');
        insert escrow;
        Phase__c phase = new Phase__c(Name = 'UAEDDS Recon Phase', EscrowAccount__c = escrow.Id);
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'UAEDDS Recon Unit', Phase__c = phase.Id, PlotNo__c = '7',
            Number_of_bedrooms__c = '2', UnitClassification__c = 'Apartment'
        );
        insert unit;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, TotalAmount__c = 100000);
        insert so;

        DirectDebitRequest__c m = new DirectDebitRequest__c(
            Account__c = person.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Approved By Bank',
            Bank_Status_Code__c = 'ACCP',
            DDA_Id__c = '80326',
            Customer_ID_Number__c = '784-1990-1234567-1',
            Customer_Id_Type__c = 'UAE Emirates Identity Card',
            CustomerAccountName__c = 'Recon Tester',
            Customer_Bank_Account_Name__c = 'Recon Tester',
            Customer_Bank_Name__c = 'First Abu Dhabi Bank',
            Customer_Bank_Account_Type__c = 'Current',
            Customer_IBAN_Number__c = 'AE070331234567890123456',
            Customer_Mobile__c = '+971561234567',
            Customer_City__c = 'Abu Dhabi',
            Commences_On__c = Date.today().addDays(-30),
            Expires_On__c = Date.today().addMonths(24),
            Maximum_Amount__c = 100000
        );
        insert m;

        // One payment Salesforce knows about. The report will also mention one it does not.
        insert new DirectDebit_Transactions__c(
            Direct_Debit_Request__c = m.Id,
            Request_Type__c = 'UAEDDS Collection',
            Transaction_Status__c = 'Initiated',
            UAEDDS_Payment_Id__c = '48954',
            Due_Date__c = Date.today().addDays(-1)
        );
    }

    /**
     * Filtered by class, not process name. UAEDDS_Service logs every callout under the same
     * UAEDDS_Reconciliation process name - which is deliberate, so both rows group together in the
     * app's log view - but only the batch's own row carries the summary message.
     */
    private static Logger__c lastLog() {
        return [
            SELECT Message__c, LogType__c, Integration_Response_Body__c
            FROM Logger__c
            WHERE ExecutingProcessName__c = 'UAEDDS_Reconciliation'
              AND ClassName__c = 'UAEDDS_ReconciliationBatch'
            ORDER BY CreatedDate DESC LIMIT 1
        ];
    }

    @IsTest
    static void knownPaymentIsAdvancedAndUnknownOneIsRaised() {
        Mock mock = new Mock(
            '[ { "id": 48954, "customerDdsRefNo": "DD-00000002", "paymentRefNo": "000001",' +
            ' "status": "ACCP", "amount": 5000, "reasonCode": "0", "remarks": "Testing",' +
            ' "ftRefNo": "DDS23120100045171" },' +
            ' { "id": 99999, "customerDdsRefNo": "DD-99999999", "paymentRefNo": "000002",' +
            ' "status": "ACCP", "amount": 12345, "reasonCode": "0", "remarks": "Testing",' +
            ' "ftRefNo": "DDS23120100045171" } ]',
            200
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_ReconciliationBatch.run(Date.newInstance(2026, 8, 19));
        Test.stopTest();

        Assert.areEqual(
            'Success',
            [SELECT Transaction_Status__c FROM DirectDebit_Transactions__c
             WHERE UAEDDS_Payment_Id__c = '48954'].Transaction_Status__c,
            'the payment we knew about was advanced'
        );

        Logger__c log = lastLog();
        Assert.isTrue(log.Message__c.contains('matched=1'), log.Message__c);
        Assert.isTrue(log.Message__c.contains('unmatched=1'), log.Message__c);
        // Money moved against a Modon mandate with no request behind it. The log has to name it.
        Assert.isTrue(log.Integration_Response_Body__c.contains('99999'), log.Integration_Response_Body__c);
        Assert.isTrue(log.Integration_Response_Body__c.contains('12345'), 'and the amount');
        Assert.areEqual('Service Exception', log.LogType__c, 'an unmatched row is not routine');

        // ISO on this endpoint, where uploadPayments takes dd/MM/yyyy.
        Assert.isTrue(mock.captured.contains('2026-08-19'), mock.captured);
    }

    @IsTest
    static void aCleanDayIsStillLogged() {
        Test.setMock(HttpCalloutMock.class, new Mock(
            '[ { "id": 48954, "customerDdsRefNo": "DD-00000002", "paymentRefNo": "000001",' +
            ' "status": "ACCP", "amount": 5000, "reasonCode": "0", "ftRefNo": "DDS231201" } ]',
            200
        ));

        Test.startTest();
        UAEDDS_ReconciliationBatch.run(Date.today().addDays(-1));
        Test.stopTest();

        Logger__c log = lastLog();
        Assert.isTrue(log.Message__c.contains('unmatched=0'), log.Message__c);
        Assert.areEqual('Callout Log', log.LogType__c);
        // Every run is logged, so a job that silently stopped is distinguishable from a clean day.
        Assert.areEqual('nothing unmatched', log.Integration_Response_Body__c);
    }

    @IsTest
    static void anEmptyDayIsNotAnOutage() {
        // A date with no activity answers 404 with a body that does not parse.
        Test.setMock(HttpCalloutMock.class, new Mock('<html>404 Not Found</html>', 404));

        Test.startTest();
        UAEDDS_ReconciliationBatch.run(Date.today().addDays(-1));
        Test.stopTest();

        Logger__c log = lastLog();
        Assert.isTrue(log.Message__c.contains('empty day'), log.Message__c);
        Assert.areEqual('Callout Log', log.LogType__c, 'a quiet day is not a failure');
    }

    @IsTest
    static void anUnreadableReportIsAFailure() {
        Test.setMock(HttpCalloutMock.class, new Mock('<html>500 gateway error</html>', 500));

        Test.startTest();
        UAEDDS_ReconciliationBatch.run(Date.today().addDays(-1));
        Test.stopTest();

        Logger__c log = lastLog();
        Assert.isTrue(log.Message__c.contains('unreadable'), log.Message__c);
        Assert.areEqual('Service Exception', log.LogType__c);
    }

    /**
     * A body that parses and carries rows, none of which names a payment. Distinct from an empty
     * day: the report answered, so the job ran - it simply had nothing to reconcile against.
     */
    @IsTest
    static void aReportWithNoPaymentRowsIsLoggedAsSuch() {
        Test.setMock(HttpCalloutMock.class, new Mock(
            '[ { "customerDdsRefNo": "DD-00000002", "status": "ACCP", "amount": 5000 } ]', 200
        ));

        Test.startTest();
        UAEDDS_ReconciliationBatch.run(Date.today().addDays(-1));
        Test.stopTest();

        Logger__c log = lastLog();
        Assert.isTrue(log.Message__c.contains('no payment rows'), log.Message__c);
        Assert.areEqual('Callout Log', log.LogType__c, 'nothing was reconciled and nothing failed');
    }

    /**
     * The live system answers HTTP 200 with zero bytes for a date with no activity, rather than the
     * 404 the captured evidence showed. Parsing that used to throw a JSONException.
     */
    @IsTest
    static void anEmptyBodyIsAQuietDayRatherThanAnOutage() {
        Test.setMock(HttpCalloutMock.class, new Mock('', 200));

        Test.startTest();
        UAEDDS_ReconciliationBatch.run(Date.today().addDays(-1));
        Test.stopTest();

        Logger__c log = lastLog();
        Assert.isTrue(log.Message__c.contains('no payment rows'), log.Message__c);
        Assert.areEqual('Callout Log', log.LogType__c, 'a quiet day is not a failure');
    }

    @IsTest
    static void schedulerRegisters() {
        Test.startTest();
        Assert.isNotNull(
            System.schedule('UAEDDS recon test', '0 0 7 * * ?', new UAEDDS_ReconciliationBatch())
        );
        Test.stopTest();
    }
}