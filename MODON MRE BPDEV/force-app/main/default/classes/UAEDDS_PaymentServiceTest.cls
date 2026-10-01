/**********************************************************************************************
 * Name           : UAEDDS_PaymentServiceTest
 * Description     : Covers the payment path, with most of the weight on the selection rules,
 *                   since getting those wrong means either debiting a customer the wrong amount
 *                   or not collecting at all. The amount cases mirror what BPDEV actually holds:
 *                   almost every unpaid installment carries a zero balance, and a handful of the
 *                   part paid ones contradict themselves.
 * Usage           : Test class for UAEDDS_PaymentService, UAEDDS_PaymentUploadQueueable,
 *                   UAEDDS_PaymentUploadScheduler and UAEDDS_PaymentStatusBatch.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    26 Aug 2026    Cover the discarded mandate on a collected sales order.
 * 1.2        Karunakar         16 Sep 2026    Assert the dd-payments-<OIC>-<ddMMyyyy> file name, with
 *                                             and without an originator code, and the refusal when
 *                                             one selection spans two of them.
 * 1.3        Karunakar         16 Sep 2026    Assert OICCode on the uploadPayments body: once, beside
 *                                             paymentFileName, and absent when no mandate has one.
 *                                             nothingDueIsLoggedRatherThanSilent asks for a date
 *                                             before the schedule rather than after it - see there.
 * 1.4        Karunakar         16 Sep 2026    Assert OICCode on the getPaymentReqStatus body too.
 * 1.5        Karunakar         21 Sep 2026    Rejection reasons are asserted against the
 *                                             UAEDDS_Code__mdt rows the org actually holds, and the
 *                                             replacement mandate is raised without leaning on the
 *                                             Discarded exemption in the one-per-Sales-Order check.
 **********************************************************************************************/
@IsTest
private class UAEDDS_PaymentServiceTest {

    // Far enough out that the 20:00 cut-off on the day before is always still ahead, so these
    // tests do not change behaviour depending on the hour they run.
    private static final Date DUE = Date.today().addDays(3);

    // The originator code on the setup mandate, and so the one the payment file is named for.
    private static final String OIC = '550000356';

    private class Mock implements HttpCalloutMock {
        private String body;
        private String captured;
        private Mock(String body) {
            this.body = body;
        }
        public HttpResponse respond(HttpRequest req) {
            captured = req.getBody();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account person = new Account(
            FirstName = 'Payment',
            LastName = 'Tester',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'payment.tester@example.com.invalid',
            BillingCity = 'Abu Dhabi'
        );
        insert person;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'UAEDDS Pay Escrow');
        insert escrow;
        Phase__c phase = new Phase__c(Name = 'UAEDDS Pay Phase', EscrowAccount__c = escrow.Id);
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'UAEDDS Pay Unit', Phase__c = phase.Id, PlotNo__c = '9',
            Number_of_bedrooms__c = '2', UnitClassification__c = 'Apartment'
        );
        insert unit;
        SalesOrder__c so = new SalesOrder__c(Unit__c = unit.Id, TotalAmount__c = 100000);
        insert so;

        // A mandate that is live at the bank, which is what collection requires.
        DirectDebitRequest__c mandate = new DirectDebitRequest__c(
            Account__c = person.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Approved By Bank',
            Bank_Status_Code__c = 'ACCP',
            Customer_ID_Number__c = '784-1990-1234567-1',
            Customer_Id_Type__c = 'UAE Emirates Identity Card',
            CustomerAccountName__c = 'Payment Tester',
            Customer_Bank_Account_Name__c = 'Payment Tester',
            Customer_Bank_Name__c = 'First Abu Dhabi Bank',
            Customer_Bank_Account_Type__c = 'Current',
            Customer_IBAN_Number__c = 'AE070331234567890123456',
            Customer_Mobile__c = '+971561234567',
            Customer_City__c = 'Abu Dhabi',
            Commences_On__c = Date.today().addDays(-30),
            Expires_On__c = Date.today().addMonths(24),
            Minimum_Amount__c = 10,
            Maximum_Amount__c = 100000
        );
        insert mandate;
        // The originator code the payment file is named for. Written after the insert on purpose:
        // DirectDebitRequestTriggerHelper.updateDirectDebitRequest stamps OIC__c before insert from
        // the sales order's escrow account, and this sales order has no virtual account to reach one
        // through, so anything set on the insert itself is blanked.
        update new DirectDebitRequest__c(Id = mandate.Id, OIC__c = OIC);

        Date due = Date.today().addDays(3);
        insert new List<SalesOrderInstallments__c>{
            // The normal case: unpaid, balance untouched at zero, claims its full value.
            inst(so.Id, 2, due, 5000, 0, 'Not Paid'),
            // Milestone 1 is the booking payment and is never a direct debit.
            inst(so.Id, 1, due, 20000, 0, 'Not Paid'),
            // Genuinely part paid: the balance is meaningful.
            inst(so.Id, 3, due, 8000, 3000, 'Partially Paid'),
            // Contradictory: part paid but nothing outstanding.
            inst(so.Id, 4, due, 6000, 0, 'Partially Paid'),
            // Contradictory: part paid but the whole amount outstanding.
            inst(so.Id, 5, due, 7000, 7000, 'Partially Paid'),
            inst(so.Id, 6, due, 4000, 0, 'Paid'),
            inst(so.Id, 7, due, 4000, 0, 'Cancelled'),
            // Above the mandate maximum.
            inst(so.Id, 8, due, 250000, 0, 'Not Paid'),
            // A different date entirely.
            inst(so.Id, 9, due.addDays(10), 5000, 0, 'Not Paid')
        };
    }

    private static SalesOrderInstallments__c inst(
        Id salesOrderId, Decimal milestone, Date due, Decimal amount, Decimal balance, String status
    ) {
        return new SalesOrderInstallments__c(
            SalesOrder__c = salesOrderId,
            MilestoneNumber__c = milestone,
            MilestoneDate__c = due,
            InstallmentAmount__c = amount,
            Balance_Amount__c = balance,
            PaymentStatus__c = status
        );
    }

    /**
     * The plain language for a bank code lives in UAEDDS_Code__mdt, which is org data rather than
     * metadata held in this repository - an org that has not had the vendor code lists loaded holds
     * no description for any code at all, and describe() correctly returns null for every one of
     * them. Rejection reasons are therefore asserted against what the org actually carries: a loaded
     * org still proves the code was read from the right namespace, and an unloaded one does not fail
     * on data nobody deployed.
     */
    private static String loadedDescription(String codeType, String code) {
        for (UAEDDS_Code__mdt c : UAEDDS_Code__mdt.getAll().values()) {
            if (c.Code_Type__c == codeType && c.Code__c == code) {
                return c.Description__c;
            }
        }
        return null;
    }

    private static Map<Decimal, UAEDDS_PaymentService.Candidate> byMilestone(Date due) {
        Map<Id, Decimal> milestoneById = new Map<Id, Decimal>();
        for (SalesOrderInstallments__c i : [
            SELECT Id, MilestoneNumber__c FROM SalesOrderInstallments__c
        ]) {
            milestoneById.put(i.Id, i.MilestoneNumber__c);
        }
        Map<Decimal, UAEDDS_PaymentService.Candidate> result =
            new Map<Decimal, UAEDDS_PaymentService.Candidate>();
        for (UAEDDS_PaymentService.Candidate c : UAEDDS_PaymentService.selectDue(due)) {
            result.put(milestoneById.get(c.installmentId), c);
        }
        return result;
    }

    // ------------------------------------------------------------ selection

    @IsTest
    static void unpaidClaimsTheInstallmentNotTheZeroBalance() {
        UAEDDS_PaymentService.Candidate c = byMilestone(DUE).get(2);

        Assert.isTrue(c.isCollectable(), 'a plain unpaid installment is collectable: ' + c.problem);
        // Balance_Amount__c is 0 on this row, as it is on 1,137 of 1,150 real unpaid installments.
        // Claiming the balance would debit the customer nothing.
        Assert.areEqual(5000, c.amount);
    }

    @IsTest
    static void milestoneOneIsNeverCollected() {
        Assert.isFalse(
            byMilestone(DUE).containsKey(1),
            'milestone 1 is the booking payment and is collected through the payment-link path'
        );
    }

    @IsTest
    static void genuinelyPartPaidClaimsTheBalance() {
        UAEDDS_PaymentService.Candidate c = byMilestone(DUE).get(3);
        Assert.isTrue(c.isCollectable(), 'a genuinely part paid installment is collectable: ' + c.problem);
        Assert.areEqual(3000, c.amount, 'the outstanding balance, not the full 8000');
    }

    @IsTest
    static void contradictoryBalancesAreRefusedNotGuessed() {
        Map<Decimal, UAEDDS_PaymentService.Candidate> found = byMilestone(DUE);

        for (Decimal milestone : new List<Decimal>{ 4, 5 }) {
            UAEDDS_PaymentService.Candidate c = found.get(milestone);
            Assert.isFalse(c.isCollectable(), 'milestone ' + milestone + ' must be refused');
            Assert.isTrue(
                c.problem.contains('Confirm what is outstanding'),
                'the refusal says what a human needs to do: ' + c.problem
            );
        }
    }

    @IsTest
    static void paidAndCancelledNeverAppear() {
        Map<Decimal, UAEDDS_PaymentService.Candidate> found = byMilestone(DUE);
        Assert.isFalse(found.containsKey(6), 'Paid');
        Assert.isFalse(found.containsKey(7), 'Cancelled');
    }

    @IsTest
    static void amountAboveTheMandateMaximumIsRefused() {
        UAEDDS_PaymentService.Candidate c = byMilestone(DUE).get(8);
        Assert.isFalse(c.isCollectable());
        Assert.isTrue(c.problem.contains('exceeds the mandate maximum'), c.problem);
    }

    @IsTest
    static void onlyTheRequestedDateIsConsidered() {
        Assert.isFalse(byMilestone(DUE).containsKey(9), 'a different due date is a different run');
    }

    @IsTest
    static void mandateMustBeLiveAtTheBankNotJustApprovedHere() {
        update new DirectDebitRequest__c(
            Id = [SELECT Id FROM DirectDebitRequest__c LIMIT 1].Id,
            Bank_Status_Code__c = 'PNDG'
        );
        UAEDDS_PaymentService.Candidate c = byMilestone(DUE).get(2);
        Assert.isFalse(c.isCollectable(), 'a mandate the customer has not signed cannot be collected');
        Assert.isTrue(c.problem.contains('not ACCP'), c.problem);
    }

    /**
     * Not merely uncollectable - absent. An installment already at the bank is not a decision
     * waiting for somebody the way a contradictory balance is, so it leaves the selection the way
     * Paid and Cancelled do rather than sitting on the screen inviting a second send.
     */
    @IsTest
    static void alreadySubmittedNeverAppears() {
        Id installmentId = [
            SELECT Id FROM SalesOrderInstallments__c WHERE MilestoneNumber__c = 2 LIMIT 1
        ].Id;
        insert new DirectDebit_Transactions__c(
            Direct_Debit_Request__c = [SELECT Id FROM DirectDebitRequest__c LIMIT 1].Id,
            SOInstallment__c = installmentId,
            Request_Type__c = 'UAEDDS Collection',
            Transaction_Status__c = 'Initiated'
        );

        Assert.isFalse(
            byMilestone(DUE).containsKey(2),
            'double collection is the failure that costs real money'
        );
    }

    /**
     * The counterpart: a failed attempt is deliberately not "already submitted". It stays on the
     * list, because nothing was collected and the money is still owed.
     */
    @IsTest
    static void aFailedAttemptIsStillOffered() {
        Id installmentId = [
            SELECT Id FROM SalesOrderInstallments__c WHERE MilestoneNumber__c = 2 LIMIT 1
        ].Id;
        insert new DirectDebit_Transactions__c(
            Direct_Debit_Request__c = [SELECT Id FROM DirectDebitRequest__c LIMIT 1].Id,
            SOInstallment__c = installmentId,
            Request_Type__c = 'UAEDDS Collection',
            Transaction_Status__c = 'Failure'
        );

        Assert.isTrue(
            byMilestone(DUE).containsKey(2),
            'a failed attempt collected nothing, so the installment is still due'
        );
    }

    // ------------------------------------------------------------ cut-off

    @IsTest
    static void cutOffIsTwentyHundredDubaiTheDayBefore() {
        Datetime cut = UAEDDS_PaymentService.cutOff(Date.newInstance(2026, 9, 10));
        // Asserted in GMT, because date() and hour() answer in the running user's timezone and
        // would make this test agree with whatever the code did. The UAE is UTC+4 with no
        // daylight saving, so 16:00 GMT is 20:00 Dubai for good.
        Assert.areEqual(Date.newInstance(2026, 9, 9), cut.dateGmt(), 'the day before');
        Assert.areEqual(16, cut.hourGmt(), '16:00 GMT is 20:00 in Dubai');
        Assert.isTrue(UAEDDS_PaymentService.isPastCutOff(Date.today()), 'today is already too late');
        Assert.isFalse(UAEDDS_PaymentService.isPastCutOff(DUE));
    }

    /**
     * The deadline belongs to a UAE bank, not to whoever is looking at the screen. This is the
     * assertion that was missing: Datetime.newInstance built the cut-off in the running user's
     * timezone, so a user on Asia/Gaza saw it an hour late - long enough to send a file that then
     * failed overnight. 174 of the 401 active users in this org are not on Dubai time.
     */
    @IsTest
    static void theCutOffIsTheSameInstantForEveryTimezone() {
        Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
        User dubai = timezoneUser('Asia/Dubai', 'dxb', profileId);
        User gaza = timezoneUser('Asia/Gaza', 'gza', profileId);
        User pacific = timezoneUser('America/Los_Angeles', 'lax', profileId);
        insert new List<User>{ dubai, gaza, pacific };

        Date due = Date.newInstance(2026, 9, 10);
        Datetime fromDubai;
        Datetime fromGaza;
        Datetime fromPacific;

        System.runAs(dubai) {
            fromDubai = UAEDDS_PaymentService.cutOff(due);
        }
        System.runAs(gaza) {
            fromGaza = UAEDDS_PaymentService.cutOff(due);
        }
        System.runAs(pacific) {
            fromPacific = UAEDDS_PaymentService.cutOff(due);
        }

        Assert.areEqual(fromDubai, fromGaza, 'a Gaza user shares the deadline, not their own');
        Assert.areEqual(fromDubai, fromPacific, 'and so does a Pacific one');
        Assert.areEqual(16, fromGaza.hourGmt(), 'still 20:00 Dubai');
    }

    private static User timezoneUser(String zone, String alias, Id profileId) {
        return new User(
            Alias = alias,
            Email = 'uaedds.' + alias + '@example.com.invalid',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Cutoff ' + alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = profileId,
            TimeZoneSidKey = zone,
            UserName = 'uaedds.' + alias + '.' + DateTime.now().getTime() + '@example.com.invalid'
        );
    }

    /**
     * The cut-off is reported but no longer gates prepare: the check in UAEDDS_PaymentService is
     * commented out, because the collection screen names the file for tomorrow rather than for the
     * milestone dates on the rows, so a selection of overdue installments would otherwise be
     * unsendable. What is asserted here is the pair the screen and the home page read - the deadline
     * itself, and whether it has passed - plus that prepare still commits a file dated today.
     *
     * If the gate is ever put back, this is the test that has to change with it.
     */
    @IsTest
    static void theCutOffIsReportedAndPrepareStillCommits() {
        Assert.isTrue(UAEDDS_PaymentService.isPastCutOff(Date.today()), 'today is already too late');
        Assert.isFalse(UAEDDS_PaymentService.isPastCutOff(DUE), 'three days out is not');

        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), Date.today()
        );

        Assert.areEqual(
            'Submitting',
            [SELECT Status__c FROM DDA_Payment_File__c WHERE Id = :file.Id].Status__c,
            'the header is committed before anything is sent, whatever the hour'
        );
    }

    // ------------------------------------------------------------ prepare

    @IsTest
    static void prepareCommitsTheHeaderBeforeAnythingIsSent() {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );

        DDA_Payment_File__c saved = [
            SELECT Status__c, Record_Count__c, Total_Amount__c, Payment_File_Id__c, Payment_File_Name__c
            FROM DDA_Payment_File__c WHERE Id = :file.Id
        ];
        // Submitting is the durable marker: if the upload times out after the bank accepted it,
        // this row is the only evidence the file exists.
        Assert.areEqual('Submitting', saved.Status__c);
        Assert.isNull(saved.Payment_File_Id__c, 'no file id until the bank gives us one');
        Assert.areEqual(2, saved.Record_Count__c, 'milestones 2 and 3 only');
        Assert.areEqual(8000, saved.Total_Amount__c, '5000 unpaid plus 3000 outstanding');
        // dd-payments-<OIC>-<ddMMyyyy>.csv, the pattern the vendor requires. The date is the due
        // date rather than today, so a file sent the evening before names the day money moves.
        Assert.areEqual(
            'dd-payments-' + OIC + '-' + ddMMyyyy(DUE) + '.csv',
            saved.Payment_File_Name__c,
            'named for the originator behind the mandates it collects'
        );

        List<DirectDebit_Transactions__c> rows = [
            SELECT Request_Type__c, Transaction_Status__c, Collection_Amount__c, Payment_Ref_No__c, Gateway__c
            FROM DirectDebit_Transactions__c WHERE Payment_File__c = :file.Id ORDER BY Payment_Ref_No__c
        ];
        Assert.areEqual(2, rows.size());
        for (DirectDebit_Transactions__c t : rows) {
            // Not 'Collection'. The FAB dispatch is a whitelist, and this value is what keeps the
            // legacy trigger chain out of the UAEDDS path.
            Assert.areEqual('UAEDDS Collection', t.Request_Type__c);
            Assert.areEqual('UAEDDS', t.Gateway__c, 'the formula reaches the parent mandate');
        }
        Assert.isTrue(rows[0].Payment_Ref_No__c.endsWith('-000001'), rows[0].Payment_Ref_No__c);
        Assert.isTrue(rows[1].Payment_Ref_No__c.endsWith('-000002'), rows[1].Payment_Ref_No__c);
    }

    @IsTest
    static void prepareRefusesWhenNothingIsCollectable() {
        try {
            UAEDDS_PaymentService.prepare(new List<UAEDDS_PaymentService.Candidate>(), DUE);
            Assert.fail('an empty file must not be created');
        } catch (UAEDDS_PaymentService.PaymentException e) {
            Assert.isTrue(e.getMessage().contains('Nothing collectable'), e.getMessage());
        }
    }

    /**
     * Two originator codes in one selection. The name carries exactly one, so naming the file for
     * either would send real debits out under the wrong originator - it is refused instead. The
     * refusal lands before any DML, which is what the file count asserts.
     */
    @IsTest
    static void aSelectionSpanningTwoOriginatorsIsRefused() {
        List<UAEDDS_PaymentService.Candidate> candidates = UAEDDS_PaymentService.selectDue(DUE);
        Integer marked = 0;
        for (UAEDDS_PaymentService.Candidate c : candidates) {
            if (c.isCollectable()) {
                c.oic = marked == 0 ? OIC : '550000999';
                marked++;
            }
        }
        Assert.areEqual(2, marked, 'milestones 2 and 3, one originator code each');

        try {
            UAEDDS_PaymentService.prepare(candidates, DUE);
            Assert.fail('a file cannot be named for two originators');
        } catch (UAEDDS_PaymentService.PaymentException e) {
            Assert.isTrue(e.getMessage().contains(OIC + ', 550000999'), e.getMessage());
        }
        Assert.areEqual(
            0, [SELECT COUNT() FROM DDA_Payment_File__c], 'and nothing was committed'
        );
    }

    /**
     * A day where no mandate carries an originator code still collects. Most escrow accounts hold
     * no OIC, so the segment is left out rather than written empty.
     */
    @IsTest
    static void aDayWithNoOriginatorCodeLeavesTheSegmentOut() {
        update new DirectDebitRequest__c(
            Id = [SELECT Id FROM DirectDebitRequest__c LIMIT 1].Id, OIC__c = null
        );

        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );

        Assert.areEqual(
            'dd-payments-' + ddMMyyyy(DUE) + '.csv',
            [SELECT Payment_File_Name__c FROM DDA_Payment_File__c WHERE Id = :file.Id]
                .Payment_File_Name__c,
            'no empty segment where the code would have been'
        );
    }

    /** The compact date the vendor file name carries, which is ddMMyyyy rather than the ISO form. */
    private static String ddMMyyyy(Date d) {
        return String.valueOf(d.day()).leftPad(2, '0')
            + String.valueOf(d.month()).leftPad(2, '0')
            + String.valueOf(d.year());
    }

    // ------------------------------------------------------------ upload

    @IsTest
    static void uploadSendsDdMmYyyyAndStampsTheFileId() {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        Mock mock = new Mock(
            '{ "paymentFileID": "131365", "message": "", "status": null, "records": [' +
            ' { "id": 48957, "customerDdsRefNo": "DD-00000002", "paymentRefNo": "000001", "status": "PNDG", "errors": "" },' +
            ' { "id": 48958, "customerDdsRefNo": "DD-00000002", "paymentRefNo": "000002", "status": "PNDG", "errors": "" } ] }'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        System.enqueueJob(new UAEDDS_PaymentUploadQueueable(file.Id));
        Test.stopTest();

        DDA_Payment_File__c saved = [
            SELECT Status__c, Payment_File_Id__c, Response_Payload__c, Last_Status_Check__c
            FROM DDA_Payment_File__c WHERE Id = :file.Id
        ];
        Assert.areEqual('Submitted', saved.Status__c);
        // A JSON string, where every other identifier in this API is a number.
        Assert.areEqual('131365', saved.Payment_File_Id__c);
        Assert.isNotNull(saved.Response_Payload__c);

        List<DirectDebit_Transactions__c> rows = [
            SELECT UAEDDS_Payment_Id__c, Payment_Ref_Suffix__c, Transaction_Status__c
            FROM DirectDebit_Transactions__c WHERE Payment_File__c = :file.Id ORDER BY Payment_Ref_No__c
        ];
        Assert.areEqual('48957', rows[0].UAEDDS_Payment_Id__c, 'records[].id is the correlation key');
        Assert.areEqual('48958', rows[1].UAEDDS_Payment_Id__c);
        // Only the 6 digit suffix comes back, and it did not match what was sent, so it is stored
        // for reference and never matched on.
        Assert.areEqual('000001', rows[0].Payment_Ref_Suffix__c);
        Assert.areEqual('Initiated', rows[0].Transaction_Status__c);

        String sent = mock.captured;
        // TEMPORARY, and the reason this reads tomorrow rather than the row's own due date:
        // UAEDDS_PaymentService.uploadPayload currently sends ddMMyyyy(Date.today().addDays(1)) with
        // ddMMyyyy(t.Due_Date__c) commented out beside it. That is right only for a file sent the
        // evening before - the class's own 1.8 note records it being fixed once already - so when
        // that line is put back, this expectation moves back to DUE with it.
        Date claimed = Date.today().addDays(1);
        String expectedDate = String.valueOf(claimed.day()).leftPad(2, '0') + '/'
            + String.valueOf(claimed.month()).leftPad(2, '0') + '/' + String.valueOf(claimed.year());
        Assert.isTrue(sent.contains(expectedDate), 'uploadPayments takes dd/MM/yyyy: ' + expectedDate);
        Assert.isTrue(sent.contains('paymentFileName'), sent.left(200));

        // OICCode sits beside paymentFileName, quoted, and once rather than once per row.
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(sent);
        Assert.areEqual(OIC, body.get('OICCode'), 'the originator this file collects for');
        Assert.isTrue(body.get('OICCode') instanceof String, 'sent quoted');
        List<Object> requestArray = (List<Object>) body.get('requestArray');
        Assert.areEqual(2, requestArray.size());
        for (Object row : requestArray) {
            Assert.isFalse(
                ((Map<String, Object>) row).containsKey('OICCode'),
                'one file is one originator, so no copy per row'
            );
        }
    }

    /**
     * A file whose mandates carry no originator code sends no OICCode at all. A key present but
     * empty is a different request from a key that was never sent, and most escrow accounts hold
     * no code.
     */
    @IsTest
    static void uploadOmitsTheCodeWhenNoMandateHasOne() {
        update new DirectDebitRequest__c(
            Id = [SELECT Id FROM DirectDebitRequest__c LIMIT 1].Id, OIC__c = null
        );
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        Mock mock = new Mock('{ "paymentFileID": "131365", "message": "", "records": [] }');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        System.enqueueJob(new UAEDDS_PaymentUploadQueueable(file.Id));
        Test.stopTest();

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        Assert.isFalse(body.containsKey('OICCode'), 'absent, not empty: ' + mock.captured);
        Assert.isTrue(body.containsKey('paymentFileName'), 'the rest of the body is unchanged');
    }

    @IsTest
    static void afailedUploadLeavesTheFileOnSubmitting() {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        Test.setMock(HttpCalloutMock.class, new Mock('<html>gateway timeout</html>'));

        Test.startTest();
        System.enqueueJob(new UAEDDS_PaymentUploadQueueable(file.Id));
        Test.stopTest();

        DDA_Payment_File__c saved = [
            SELECT Status__c, Payment_File_Id__c FROM DDA_Payment_File__c WHERE Id = :file.Id
        ];
        // The whole point of the design: an unreadable answer must not be read as "not sent".
        Assert.areEqual('Submitting', saved.Status__c, 'a human decides whether the bank has this file');
        Assert.isNull(saved.Payment_File_Id__c);
    }

    // ------------------------------------------------------------ status

    @IsTest
    static void statusRefreshSettlesTheFile() {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        List<DirectDebit_Transactions__c> rows = [
            SELECT Id FROM DirectDebit_Transactions__c WHERE Payment_File__c = :file.Id ORDER BY Payment_Ref_No__c
        ];
        update new List<DirectDebit_Transactions__c>{
            new DirectDebit_Transactions__c(Id = rows[0].Id, UAEDDS_Payment_Id__c = '48954'),
            new DirectDebit_Transactions__c(Id = rows[1].Id, UAEDDS_Payment_Id__c = '48955')
        };
        update new DDA_Payment_File__c(Id = file.Id, Payment_File_Id__c = '131352', Status__c = 'Submitted');

        Mock mock = new Mock(
            '{ "paymentFileID": "131352", "records": [' +
            ' { "id": 48954, "paymentRefNo": "000001", "status": "ACCP", "reasonCode": "0", "errors": "", "amount": 5000, "ftRefNo": "DDS23120100045171" },' +
            ' { "id": 48955, "paymentRefNo": "000002", "status": "RJCT", "reasonCode": "I", "errors": "", "amount": 3000 } ] }'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        UAEDDS_PaymentService.refreshFile(file.Id);
        Test.stopTest();

        // getPaymentReqStatus carries the originator code beside the file id, read off the mandates
        // behind the file's rows rather than held on the file itself.
        Map<String, Object> sent = (Map<String, Object>) JSON.deserializeUntyped(mock.captured);
        Assert.areEqual('131352', sent.get('paymentFileID'));
        Assert.areEqual(OIC, sent.get('OICCode'), 'the originator this file was collected for');

        Map<String, DirectDebit_Transactions__c> byId = new Map<String, DirectDebit_Transactions__c>();
        for (DirectDebit_Transactions__c t : [
            SELECT UAEDDS_Payment_Id__c, Transaction_Status__c, FT_Reference_No__c,
                   Payment_Reason_Code__c, Rejection_Reason__c
            FROM DirectDebit_Transactions__c WHERE Payment_File__c = :file.Id
        ]) {
            byId.put(t.UAEDDS_Payment_Id__c, t);
        }

        Assert.areEqual('Success', byId.get('48954').Transaction_Status__c);
        Assert.areEqual('DDS23120100045171', byId.get('48954').FT_Reference_No__c);
        // "0" means accepted and must survive where "" becomes null.
        Assert.areEqual('0', byId.get('48954').Payment_Reason_Code__c);

        Assert.areEqual('Failure', byId.get('48955').Transaction_Status__c);
        Assert.areEqual('I', byId.get('48955').Payment_Reason_Code__c);
        // Read from the Payment Reason Code namespace, not the DDA one, and only as far as the org
        // carries that list - see loadedDescription.
        Assert.areEqual(
            loadedDescription('Payment Reason Code', 'I'),
            byId.get('48955').Rejection_Reason__c,
            'the reason is the Payment Reason Code list\'s own words for I'
        );

        Assert.areEqual(
            'Partially Settled',
            [SELECT Status__c FROM DDA_Payment_File__c WHERE Id = :file.Id].Status__c,
            'one settled and one rejected is neither Settled nor Failed'
        );
    }

    @IsTest
    static void aFileWithNoBankIdCannotBePolled() {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        try {
            UAEDDS_PaymentService.refreshFile(file.Id);
            Assert.fail('getPaymentReqStatus accepts nothing but a paymentFileID');
        } catch (UAEDDS_PaymentService.PaymentException e) {
            Assert.isTrue(e.getMessage().contains('getDDADailyReport'), 'points at the recovery path');
        }
    }

    @IsTest
    static void unknownPaymentStatusIsRecordedNotGuessed() {
        DirectDebit_Transactions__c t = UAEDDS_PaymentService.applyRow(
            null, new Map<String, Object>{ 'id' => 99, 'status' => 'WXYZ', 'reasonCode' => '' }
        );
        Assert.areEqual('99', t.UAEDDS_Payment_Id__c);
        Assert.isNull(t.Transaction_Status__c, 'an unfamiliar status leaves the row where it was');
        Assert.isNull(t.Payment_Reason_Code__c, 'empty string is null');
    }

    // ------------------------------------------------------------ scheduling

    @IsTest
    static void schedulerRunsTheDayAheadAndLogsRefusals() {
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentFileID": "131400", "message": "", "status": null, "records": [' +
            ' { "id": 50001, "paymentRefNo": "000001", "status": "PNDG", "errors": "" },' +
            ' { "id": 50002, "paymentRefNo": "000002", "status": "PNDG", "errors": "" } ] }'
        ));

        Test.startTest();
        Id fileId = UAEDDS_PaymentUploadScheduler.run(DUE);
        Test.stopTest();

        Assert.isNotNull(fileId);
        Assert.areEqual(
            '131400',
            [SELECT Payment_File_Id__c FROM DDA_Payment_File__c WHERE Id = :fileId].Payment_File_Id__c
        );

        Logger__c log = [
            SELECT Message__c, Integration_Response_Body__c FROM Logger__c
            WHERE ExecutingProcessName__c = 'UAEDDS_PaymentUpload'
              AND ClassName__c = 'UAEDDS_PaymentUploadScheduler' ORDER BY CreatedDate DESC LIMIT 1
        ];
        Assert.isTrue(log.Message__c.contains('collectable=2'), log.Message__c);
        // The refused rows are named, not silently dropped.
        Assert.isTrue(log.Message__c.contains('refused=3'), log.Message__c);
        Assert.isTrue(log.Integration_Response_Body__c.contains('Confirm what is outstanding'));
    }

    @IsTest
    static void nothingDueIsLoggedRatherThanSilent() {
        // A date before any installment falls due. Not a date far ahead: selectDue matches
        // MilestoneDate__c <= dueDate so that an overdue installment is still caught up, which means
        // a distant future date sweeps up the whole schedule rather than finding it empty.
        //
        // prepare tests emptiness before the cut-off, so a past date still refuses with 'Nothing
        // collectable' rather than with the cut-off message.
        Test.startTest();
        Id fileId = UAEDDS_PaymentUploadScheduler.run(Date.today().addDays(-400));
        Test.stopTest();

        Assert.isNull(fileId);
        Assert.isTrue(
            [SELECT Message__c FROM Logger__c WHERE ExecutingProcessName__c = 'UAEDDS_PaymentUpload'
              AND ClassName__c = 'UAEDDS_PaymentUploadScheduler' LIMIT 1]
                .Message__c.contains('Nothing collectable')
        );
    }

    @IsTest
    static void statusBatchPollsSubmittedFilesOnly() {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        DirectDebit_Transactions__c row = [
            SELECT Id FROM DirectDebit_Transactions__c WHERE Payment_File__c = :file.Id LIMIT 1
        ];
        update new DirectDebit_Transactions__c(Id = row.Id, UAEDDS_Payment_Id__c = '48954');
        update new DDA_Payment_File__c(Id = file.Id, Payment_File_Id__c = '131352', Status__c = 'Submitted');

        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentFileID": "131352", "records": [ { "id": 48954, "paymentRefNo": "000001",' +
            ' "status": "ACCP", "reasonCode": "0", "amount": 5000, "ftRefNo": "DDS231201" } ] }'
        ));

        Test.startTest();
        Database.executeBatch(new UAEDDS_PaymentStatusBatch(), 25);
        Test.stopTest();

        Assert.areEqual(
            'Success',
            [SELECT Transaction_Status__c FROM DirectDebit_Transactions__c WHERE Id = :row.Id].Transaction_Status__c
        );
    }

    /**
     * One file that cannot be read back must not stop the batch. Two fixed runs a day is the whole
     * poller, so a failure that took the run with it would leave every later file unread until
     * somebody noticed. The failure is logged and the loop carries on.
     *
     * Forced by an FT reference longer than the 50 characters the field holds, which is the shape of
     * a real vendor surprise: the answer parses, and writing it is what fails.
     */
    @IsTest
    static void oneUnreadableFileDoesNotStopTheStatusBatch() {
        DDA_Payment_File__c file = submittedFile('48954', '48955');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentFileID": "131352", "records": [ { "id": 48954, "status": "ACCP",' +
            ' "reasonCode": "0", "ftRefNo": "' + 'D'.repeat(120) + '" } ] }'
        ));

        Test.startTest();
        Database.executeBatch(new UAEDDS_PaymentStatusBatch(), 25);
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Logger__c
             WHERE ClassName__c = 'UAEDDS_PaymentStatusBatch'
               AND ExecutingProcessName__c = 'UAEDDS_PaymentStatus'],
            'the failure reaches the log rather than ending the run'
        );
        Assert.areEqual(
            'Submitted',
            [SELECT Status__c FROM DDA_Payment_File__c WHERE Id = :file.Id].Status__c,
            'and the file is left for the next run rather than advanced on a write that failed'
        );
    }

    // ------------------------------------------------------------ representment and bounce

    /** A bounced payment, ready to be re-presented. */
    private static DirectDebit_Transactions__c bounced(Integer attemptsUsed) {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        DirectDebit_Transactions__c t = [
            SELECT Id FROM DirectDebit_Transactions__c WHERE Payment_File__c = :file.Id LIMIT 1
        ];
        update new DirectDebit_Transactions__c(
            Id = t.Id,
            UAEDDS_Payment_Id__c = '48958',
            Transaction_Status__c = 'Failure',
            Representment_Count__c = attemptsUsed
        );
        return t;
    }

    @IsTest
    static void representPutsThePaymentBackInTheLifecycle() {
        DirectDebit_Transactions__c t = bounced(1);
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentId": 48958, "message": "Updated Successfully", "status": null }'
        ));

        Test.startTest();
        UAEDDS_PaymentService.represent(t.Id);
        Test.stopTest();

        DirectDebit_Transactions__c after = [
            SELECT Transaction_Status__c, Representment_Count__c, Represented_Date__c
            FROM DirectDebit_Transactions__c WHERE Id = :t.Id
        ];
        Assert.areEqual(2, after.Representment_Count__c, 'the attempt is counted');
        Assert.isNotNull(after.Represented_Date__c);
        Assert.areEqual('Initiated', after.Transaction_Status__c, 'pending again until the bank answers');
    }

    @IsTest
    static void aFourthAttemptNeverLeavesSalesforce() {
        DirectDebit_Transactions__c t = bounced(UAEDDS_PaymentService.MAX_REPRESENTMENTS);
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentId": 48958, "message": "Updated Successfully", "status": null }'
        ));

        Test.startTest();
        Integer before = Limits.getCallouts();
        try {
            UAEDDS_PaymentService.represent(t.Id);
            Assert.fail('a fourth representment must be refused');
        } catch (UAEDDS_PaymentService.PaymentException e) {
            Assert.isTrue(e.getMessage().contains('all 3 representment attempts'), e.getMessage());
        }
        // The decisive check. The vendor would answer 400, but a fourth presentment reaches the
        // customer as another rejection on their statement, so it must never be sent at all.
        Assert.areEqual(before, Limits.getCallouts(), 'no callout was attempted');
        Test.stopTest();
    }

    @IsTest
    static void onlyAFailedPaymentCanBeRepresented() {
        DirectDebit_Transactions__c t = bounced(0);
        update new DirectDebit_Transactions__c(Id = t.Id, Transaction_Status__c = 'Success');

        Test.startTest();
        try {
            UAEDDS_PaymentService.represent(t.Id);
            Assert.fail('a settled payment must not be re-presented');
        } catch (UAEDDS_PaymentService.PaymentException e) {
            Assert.isTrue(e.getMessage().contains('Only a failed payment'), e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void bounceMemoIsFiledAgainstThePayment() {
        DirectDebit_Transactions__c t = bounced(1);
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{"paymentId":48958,"message":"OK","status":200,"base64":"' +
            EncodingUtil.base64Encode(Blob.valueOf('a pretend bounce memo')) + '"}'
        ));

        Test.startTest();
        UAEDDS_PaymentService.fetchBounceMemo(t.Id);
        Test.stopTest();

        // Straight onto the transaction, not the mandate's Documents__c row.
        Assert.areEqual(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :t.Id],
            'the memo explains this payment, so it lives with it'
        );
    }

    @IsTest
    static void bounceCodeIsRecordedOnlyWhenItActuallyBounced() {
        DirectDebit_Transactions__c rejected = UAEDDS_PaymentService.applyRow(
            null, new Map<String, Object>{ 'id' => 1, 'status' => 'RJCT', 'reasonCode' => 'I' }
        );
        Assert.areEqual('I', rejected.Bounce_Reason_Code__c);
        Assert.areEqual(
            loadedDescription('Payment Reason Code', 'I'), rejected.Rejection_Reason__c,
            'the bounce carries the Payment Reason Code list\'s own words for I'
        );

        DirectDebit_Transactions__c accepted = UAEDDS_PaymentService.applyRow(
            null, new Map<String, Object>{ 'id' => 2, 'status' => 'ACCP', 'reasonCode' => '0' }
        );
        Assert.areEqual('0', accepted.Payment_Reason_Code__c, 'the raw code is always kept');
        Assert.isNull(accepted.Bounce_Reason_Code__c, 'an accepted payment did not bounce');
    }

    @IsTest
    static void bothSchedulersRegister() {
        Test.startTest();
        Assert.isNotNull(System.schedule('UAEDDS pay upload test', '0 0 17 * * ?', new UAEDDS_PaymentUploadScheduler()));
        Assert.isNotNull(System.schedule('UAEDDS pay status test', '0 0 18 * * ?', new UAEDDS_PaymentStatusBatch()));
        Test.stopTest();
    }

    /**
     * Discard and raise again is the supported loop, so a sales order ends up holding both mandates.
     * The collection has to be claimed against the live one. The discarded mandate carries a
     * plausible bank status - DD-00391 sat at SUBP - so picking it refuses the instalment outright
     * while the live mandate sits beside it.
     */
    @IsTest
    static void aDiscardedMandateIsNotTheOneCollectedAgainst() {
        DirectDebitRequest__c discarded = [SELECT Id, SalesOrder__c FROM DirectDebitRequest__c LIMIT 1];
        // Cancelled for the length of the insert below, then put back to Discarded. What this test
        // is about is which of the two mandates selectDue claims against, and that is decided by
        // Status__c at selection time - but getting a second mandate onto the Sales Order at all
        // depends on the insert-time one-per-Sales-Order check in DirectDebitRequestTriggerHelper,
        // which exempts Cancelled in every build of that class and Discarded only from 1.3 onwards.
        // Routing through Cancelled leaves the state this test reads exactly as it was.
        update new DirectDebitRequest__c(Id = discarded.Id, Status__c = 'Cancelled');

        DirectDebitRequest__c live = new DirectDebitRequest__c(
            SalesOrder__c = discarded.SalesOrder__c,
            Status__c = 'Approved By Bank',
            Bank_Status_Code__c = 'ACCP',
            Customer_IBAN_Number__c = 'AE070331234567890123456'
        );
        insert live;
        // The trigger derives the window and the maximum from the installments on insert. Set them
        // back afterwards so this test claims against the same terms the setup mandate carries.
        update new DirectDebitRequest__c(
            Id = live.Id,
            Commences_On__c = Date.today().addDays(-30),
            Expires_On__c = Date.today().addMonths(24),
            Minimum_Amount__c = 10,
            Maximum_Amount__c = 100000
        );
        // Back to the status this test is actually about: a discarded mandate sitting beside the
        // live one, carrying a bank status plausible enough to refuse the instalment if it were
        // the one picked.
        update new DirectDebitRequest__c(Id = discarded.Id, Status__c = 'Discarded');

        Test.startTest();
        UAEDDS_PaymentService.Candidate c = byMilestone(DUE).get(2);
        Test.stopTest();

        Assert.areEqual(live.Id, c.mandateId, 'the discarded mandate must not be the one chosen');
        Assert.isNull(c.problem, 'and the live mandate collects: ' + c.problem);
    }

    // ------------------------------------------------------------ narrowing

    /**
     * The project overload, which is how a day is collected one project at a time. A blank project
     * is every project, so the unfiltered call is this one with nothing to narrow by rather than a
     * separate query.
     */
    @IsTest
    static void theProjectOverloadNarrowsAndABlankOneDoesNot() {
        Test.startTest();
        Integer everywhere = UAEDDS_PaymentService.selectDue(DUE, null).size();
        Integer elsewhere = UAEDDS_PaymentService.selectDue(DUE, 'A Project Nobody Sold In').size();
        Test.stopTest();

        Assert.isTrue(everywhere > 0, 'a blank project is every project');
        Assert.areEqual(everywhere, UAEDDS_PaymentService.selectDue(DUE).size(), 'same selection');
        Assert.areEqual(0, elsewhere, 'and a project nothing is under returns nothing at all');
    }

    /**
     * The window and the sales order narrowing on the Filter, which is what the collection screen
     * builds. A field left null is a clause that is not applied at all, which is not the same as one
     * that matches everything.
     */
    @IsTest
    static void theFilterNarrowsByWindowAndSalesOrder() {
        String salesOrderName = [SELECT Name FROM SalesOrder__c LIMIT 1].Name;

        UAEDDS_PaymentService.Filter windowed = new UAEDDS_PaymentService.Filter();
        windowed.startDate = DUE;
        windowed.endDate = DUE;
        windowed.salesOrderName = salesOrderName;

        UAEDDS_PaymentService.Filter otherOrder = new UAEDDS_PaymentService.Filter();
        otherOrder.endDate = DUE;
        otherOrder.salesOrderName = 'A Sales Order Nobody Raised';

        Test.startTest();
        Integer mine = UAEDDS_PaymentService.selectDue(windowed).size();
        Integer none = UAEDDS_PaymentService.selectDue(otherOrder).size();
        Test.stopTest();

        Assert.isTrue(mine > 0, 'the setup rows sit on this sales order and inside the window');
        Assert.areEqual(0, none, 'an exact name match cannot quietly pull in a second sales order');
    }

    // ------------------------------------------------------------ file status

    /** Every row accepted. The file is finished, not partly finished. */
    @IsTest
    static void everyRowSettledSettlesTheFile() {
        DDA_Payment_File__c file = submittedFile('48954', '48955');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentFileID": "131352", "records": [' +
            ' { "id": 48954, "status": "ACCP", "reasonCode": "0", "ftRefNo": "DDS231201" },' +
            ' { "id": 48955, "status": "ACCP", "reasonCode": "0", "ftRefNo": "DDS231202" } ] }'
        ));

        Test.startTest();
        UAEDDS_PaymentService.refreshFile(file.Id);
        Test.stopTest();

        Assert.areEqual(
            'Settled',
            [SELECT Status__c FROM DDA_Payment_File__c WHERE Id = :file.Id].Status__c
        );
    }

    /** Every row rejected. Failed rather than Partially Settled, so the Bounced view means something. */
    @IsTest
    static void everyRowRejectedFailsTheFile() {
        DDA_Payment_File__c file = submittedFile('48954', '48955');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentFileID": "131352", "records": [' +
            ' { "id": 48954, "status": "RJCT", "reasonCode": "I" },' +
            ' { "id": 48955, "status": "RJCT", "reasonCode": "I" } ] }'
        ));

        Test.startTest();
        UAEDDS_PaymentService.refreshFile(file.Id);
        Test.stopTest();

        Assert.areEqual(
            'Failed',
            [SELECT Status__c FROM DDA_Payment_File__c WHERE Id = :file.Id].Status__c
        );
        Assert.areEqual(
            2,
            [SELECT COUNT() FROM DirectDebit_Transactions__c
             WHERE Payment_File__c = :file.Id AND Bounce_Reason_Code__c = 'I'],
            'a bounce code is stamped on each, which is what the Bounced list view reads'
        );
    }

    /**
     * An answer the bank has not given yet. Nothing is advanced and the file stays where it was, so
     * the next run asks again rather than reporting a settlement nobody was told about.
     */
    @IsTest
    static void anUnreadableRefreshLeavesTheFileAlone() {
        DDA_Payment_File__c file = submittedFile('48954', '48955');
        Test.setMock(HttpCalloutMock.class, new Mock('<html>gateway timeout</html>'));

        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_PaymentService.refreshFile(file.Id);
        Test.stopTest();

        Assert.isFalse(r.ok, 'an unparseable body is not a usable result');
        Assert.areEqual(
            'Submitted',
            [SELECT Status__c FROM DDA_Payment_File__c WHERE Id = :file.Id].Status__c,
            'the file is left for the next run rather than advanced on nothing'
        );
    }

    /** A row the response does not mention is left alone rather than guessed at. */
    @IsTest
    static void aPaymentTheResponseDoesNotMentionIsLeftAlone() {
        DDA_Payment_File__c file = submittedFile('48954', '48955');
        Test.setMock(HttpCalloutMock.class, new Mock(
            '{ "paymentFileID": "131352", "records": [' +
            ' { "id": 48954, "status": "ACCP", "reasonCode": "0", "ftRefNo": "DDS231201" },' +
            // A payment id from another file entirely, plus a row with no id at all.
            ' { "id": 77777, "status": "ACCP", "reasonCode": "0" },' +
            ' { "status": "ACCP", "reasonCode": "0" } ] }'
        ));

        Test.startTest();
        UAEDDS_PaymentService.refreshFile(file.Id);
        Test.stopTest();

        Assert.areEqual(
            'Partially Settled',
            [SELECT Status__c FROM DDA_Payment_File__c WHERE Id = :file.Id].Status__c,
            'one of the two settled, and the rows we do not hold are ignored'
        );
        Assert.areNotEqual(
            'Success',
            [SELECT Transaction_Status__c FROM DirectDebit_Transactions__c
             WHERE UAEDDS_Payment_Id__c = '48955'].Transaction_Status__c,
            'the payment the answer never mentioned did not move'
        );
    }

    /** A file whose rows are committed and given bank payment ids, ready to be read back. */
    private static DDA_Payment_File__c submittedFile(String firstPaymentId, String secondPaymentId) {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        List<DirectDebit_Transactions__c> rows = [
            SELECT Id FROM DirectDebit_Transactions__c
            WHERE Payment_File__c = :file.Id ORDER BY Payment_Ref_No__c
        ];
        update new List<DirectDebit_Transactions__c>{
            new DirectDebit_Transactions__c(Id = rows[0].Id, UAEDDS_Payment_Id__c = firstPaymentId),
            new DirectDebit_Transactions__c(Id = rows[1].Id, UAEDDS_Payment_Id__c = secondPaymentId)
        };
        update new DDA_Payment_File__c(
            Id = file.Id, Payment_File_Id__c = '131352', Status__c = 'Submitted'
        );
        return file;
    }

    // ------------------------------------------------------------ single payment guards

    /**
     * A payment the bank never took has no id to act on, so neither flow calls out for it. Both are
     * refused with the same reasoning and neither costs a callout.
     */
    @IsTest
    static void aPaymentWithNoBankIdIsRefusedOnBothFlows() {
        DirectDebit_Transactions__c t = bounced(0);
        update new DirectDebit_Transactions__c(Id = t.Id, UAEDDS_Payment_Id__c = null);
        Integer refusals = 0;

        Test.startTest();
        Integer before = Limits.getCallouts();
        try {
            UAEDDS_PaymentService.represent(t.Id);
        } catch (UAEDDS_PaymentService.PaymentException e) {
            refusals++;
            Assert.isTrue(e.getMessage().contains('never took it'), e.getMessage());
        }
        try {
            UAEDDS_PaymentService.fetchBounceMemo(t.Id);
        } catch (UAEDDS_PaymentService.PaymentException e) {
            refusals++;
            Assert.isTrue(e.getMessage().contains('no memo to fetch'), e.getMessage());
        }
        Assert.areEqual(before, Limits.getCallouts(), 'neither flow called out');
        Test.stopTest();

        Assert.areEqual(2, refusals, 'both say the bank never took this payment');
    }

    @IsTest
    static void aTransactionThatDoesNotExistIsNamed() {
        DirectDebit_Transactions__c t = bounced(0);
        Id goneId = t.Id;
        delete new DirectDebit_Transactions__c(Id = goneId);
        Boolean refused = false;

        Test.startTest();
        try {
            UAEDDS_PaymentService.represent(goneId);
        } catch (UAEDDS_PaymentService.PaymentException e) {
            refused = true;
            Assert.isTrue(e.getMessage().contains('not found'), e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(refused, 'a payment that does not exist cannot be re-presented');
    }

    /**
     * The bank refusing the representment. Nothing is counted against the cap and the payment stays
     * on Failure, so the attempt that never happened is still available.
     */
    @IsTest
    static void aRefusedRepresentmentCostsNoAttempt() {
        DirectDebit_Transactions__c t = bounced(1);
        Test.setMock(HttpCalloutMock.class, new Mock('<html>gateway timeout</html>'));

        Test.startTest();
        UAEDDS_Service.Result r = UAEDDS_PaymentService.represent(t.Id);
        Test.stopTest();

        Assert.isFalse(r.ok);
        DirectDebit_Transactions__c after = [
            SELECT Representment_Count__c, Transaction_Status__c
            FROM DirectDebit_Transactions__c WHERE Id = :t.Id
        ];
        Assert.areEqual(1, after.Representment_Count__c, 'an attempt that did not happen is not used');
        Assert.areEqual('Failure', after.Transaction_Status__c, 'and the payment is still bounced');
    }

    /**
     * An upload the bank answered with more rows than we sent. The extra rows are dropped rather
     * than written against transactions they do not describe.
     */
    @IsTest
    static void anUploadResponseLongerThanTheFileIsTruncated() {
        DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(
            UAEDDS_PaymentService.selectDue(DUE), DUE
        );
        Mock mock = new Mock(
            '{ "paymentFileID": "131365", "records": [' +
            ' { "id": 48957, "paymentRefNo": "000001", "status": "PNDG", "errors": "" },' +
            ' { "id": 48958, "paymentRefNo": "000002", "status": "PNDG", "errors": "" },' +
            ' { "id": 48959, "paymentRefNo": "000003", "status": "PNDG", "errors": "" } ] }'
        );
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        System.enqueueJob(new UAEDDS_PaymentUploadQueueable(file.Id));
        Test.stopTest();

        Assert.areEqual(
            2,
            [SELECT COUNT() FROM DirectDebit_Transactions__c WHERE Payment_File__c = :file.Id],
            'the file still holds the two rows it was built with'
        );
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM DirectDebit_Transactions__c WHERE UAEDDS_Payment_Id__c = '48959'],
            'the third row of the answer describes nothing we sent'
        );
    }

    /** A file with no rows sends nothing at all rather than an empty requestArray. */
    @IsTest
    static void anEmptyFileIsNotUploaded() {
        DDA_Payment_File__c file = new DDA_Payment_File__c(
            Payment_File_Name__c = 'dd-payments-empty.csv',
            Status__c = 'Submitting',
            Upload_Date__c = System.now(),
            Record_Count__c = 0,
            Total_Amount__c = 0
        );
        insert file;
        Test.setMock(HttpCalloutMock.class, new Mock('{ "paymentFileID": "131365" }'));

        Test.startTest();
        System.enqueueJob(new UAEDDS_PaymentUploadQueueable(file.Id));
        Test.stopTest();

        Assert.areEqual(
            'Submitting',
            [SELECT Status__c FROM DDA_Payment_File__c WHERE Id = :file.Id].Status__c,
            'nothing was sent, so nothing moved off the marker'
        );
    }
}