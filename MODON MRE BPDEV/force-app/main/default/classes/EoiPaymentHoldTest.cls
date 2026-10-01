/**********************************************************************************************
 * Name           : EoiPaymentHoldTest
 * Description     : Coverage for authorize-and-capture: the capture-mode policy, the EOI raised on
 *                   a hold, the receipt that follows on capture, the payload guard that stops a
 *                   console top-up being receipted twice, and the EOI closed when a hold lapses.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.2        Prateek Bansal    21 Sep 2026    A hold that lapsed on its own keeps its EOI, for recovery.
 * 1.1        Prateek Bansal    13 Sep 2026    Receipt carries the CKO reference, so assert that.
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class EoiPaymentHoldTest {

    private static final Decimal RANGE_AMOUNT = 650000;

    @TestSetup
    static void seed() {
        Account acc = new Account(Name = 'EOI Hold Account', Phone = '+971500000000');
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id, FirstName = 'Hold', LastName = 'Contact',
            Email = 'hold.contact@example.com', MobilePhone = '+971500000001'
        );
        insert con;
        Opportunity opp = new Opportunity(
            Name = 'EOI Hold Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        putIfFieldExists(opp, 'ContactId', con.Id);
        insert opp;

        SObject project = createProject('EOI Hold Project');
        createRange((Id) project.get('Id'), RANGE_AMOUNT);
    }

    // ── The capture-mode policy ──────────────────────────────────────────────

    @IsTest
    static void captureModeIsPerChannelAndOffWhenTheLabelIsEmpty() {
        EoiPaymentPolicy.captureChannelsOverride = 'Salesforce';
        System.assertEquals(true, EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_SALESFORCE),
            'A listed channel charges on payment');
        System.assertEquals(false, EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_BROKER),
            'A channel absent from the list only authorizes');

        EoiPaymentPolicy.captureChannelsOverride = ' broker , microsite ';
        System.assertEquals(true, EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_BROKER),
            'Entries are trimmed and matched without case');
        System.assertEquals(false, EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_SALESFORCE),
            'Salesforce is not in this list');

        EoiPaymentPolicy.captureChannelsOverride = '';
        System.assertEquals(false, EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_SALESFORCE),
            'Emptying the label puts every channel on a hold');
    }

    // ── The EOI on a hold ────────────────────────────────────────────────────

    @IsTest
    static void anAuthorizedPaymentRaisesAHeldEoiAndNoReceipt() {
        useSeededUnidentifiedAccount();
        Checkout_Payment__c cp = newPayment('CKO-HOLD', 'Authorized');

        Test.startTest();
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ cp });
        Test.stopTest();

        Checkout_Payment__c refreshed = [
            SELECT Expression_of_Interest__c, Receipt__c FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertNotEquals(null, refreshed.Expression_of_Interest__c, 'The hold raises the EOI immediately');
        System.assertEquals(null, refreshed.Receipt__c, 'No receipt until the money is actually taken');

        Expressionofinterest__c eoi = [
            SELECT Status__c, Skip_SLA__c, PaymentStatus__c, Account__c
            FROM Expressionofinterest__c WHERE Id = :refreshed.Expression_of_Interest__c
        ];
        System.assertEquals(EoiPaymentPolicy.STATUS_PAYMENT_AUTHORIZED, eoi.Status__c, 'The EOI records the hold');
        System.assertEquals(true, eoi.Skip_SLA__c, 'A held EOI is out of the SLA: the money is already held');
        System.assertEquals('Not Paid', eoi.PaymentStatus__c,
            'PaymentStatus stays Not Paid so the receipt flow can still move it to Paid');
        System.assertEquals(oppAccountId(), eoi.Account__c,
            'The EOI keeps the opportunity account - only the receipt is unidentified');

        System.assertEquals(0, [SELECT COUNT() FROM Receipt__c WHERE ExpressionOfInterest__c = :eoi.Id],
            'A hold creates no receipt');
    }

    @IsTest
    static void capturingAHeldPaymentCreatesTheReceipt() {
        useSeededUnidentifiedAccount();
        Checkout_Payment__c cp = newPayment('CKO-HOLD-THEN-CAP', 'Authorized');
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ cp });

        Checkout_Payment__c held = [
            SELECT Id, Status__c, Reference__c, Payment_Id__c, Currency_Code__c, EOI_Creation_Payload__c,
                   Expression_of_Interest__c, Receipt__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        held.Status__c = EoiPaymentPolicy.STATUS_CAPTURED;

        Test.startTest();
        CheckoutEoiMaterializer.receiptCapturedEois(new List<Checkout_Payment__c>{ held });
        Test.stopTest();

        Checkout_Payment__c refreshed = [
            SELECT Expression_of_Interest__c, Receipt__c FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        System.assertNotEquals(null, refreshed.Receipt__c, 'Capture receipts the EOI raised on the hold');

        Receipt__c rec = [
            SELECT Account__c, Is_Un_Identified_Receipts__c, Modeofpayment__c, Status__c,
                   Receipt_Type__c, TransactionNumber__c, ExpressionOfInterest__c
            FROM Receipt__c WHERE Id = :refreshed.Receipt__c
        ];
        System.assertEquals(refreshed.Expression_of_Interest__c, rec.ExpressionOfInterest__c, 'Receipt sits on the EOI');
        System.assertEquals(seededAccountId(), rec.Account__c, 'Receipt books to the unidentified finance account');
        System.assertEquals(true, rec.Is_Un_Identified_Receipts__c, 'Flagged unidentified for the finance route');
        System.assertEquals('EOI Receipt', rec.Receipt_Type__c, 'Receipt type');
        System.assertEquals('Online', rec.Modeofpayment__c, 'Online is the only EOI payment method');
        System.assertEquals('CKO-HOLD-THEN-CAP', rec.TransactionNumber__c, 'Receipt carries the CKO reference');

        System.assertEquals(1, [SELECT COUNT() FROM Receipt__c WHERE ExpressionOfInterest__c = :rec.ExpressionOfInterest__c],
            'Exactly one receipt, not one per pass');
    }

    @IsTest
    static void aTopUpWithNoPayloadIsNeverReceipted() {
        useSeededUnidentifiedAccount();
        // A console top-up against an EOI that already exists: no creation payload. Receipting it
        // would book the same money a second time against an EOI that is already paid.
        Checkout_Payment__c cp = newPayment('CKO-HOLD-TOPUP', 'Authorized');
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ cp });
        Checkout_Payment__c topUp = [
            SELECT Id, Status__c, Reference__c, Payment_Id__c, Currency_Code__c,
                   Expression_of_Interest__c, Receipt__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id
        ];
        topUp.Status__c = EoiPaymentPolicy.STATUS_CAPTURED;
        topUp.EOI_Creation_Payload__c = null;

        Test.startTest();
        CheckoutEoiMaterializer.receiptCapturedEois(new List<Checkout_Payment__c>{ topUp });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Receipt__c WHERE ExpressionOfInterest__c = :topUp.Expression_of_Interest__c],
            'A row with no creation payload is left alone');
    }

    // ── The EOI when a hold lapses ───────────────────────────────────────────

    @IsTest
    static void aLapsedHoldClosesItsEoiAndLeavesACapturedOneAlone() {
        useSeededUnidentifiedAccount();
        Checkout_Payment__c heldPayment = newPayment('CKO-HOLD-LAPSE', 'Authorized');
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ heldPayment });
        Checkout_Payment__c capturedPayment = newPayment('CKO-CAP-KEEP', EoiPaymentPolicy.STATUS_CAPTURED);
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ capturedPayment });

        Checkout_Payment__c lapsed = [
            SELECT Id, Status__c, Reference__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Id = :heldPayment.Id
        ];
        lapsed.Status__c = 'Expired';
        Checkout_Payment__c kept = [
            SELECT Id, Status__c, Reference__c, Expression_of_Interest__c
            FROM Checkout_Payment__c WHERE Id = :capturedPayment.Id
        ];
        kept.Status__c = 'Voided';

        Test.startTest();
        CheckoutEoiMaterializer.closeLapsedEois(new List<Checkout_Payment__c>{ lapsed, kept });
        Test.stopTest();

        Expressionofinterest__c closed = [
            SELECT Status__c, SLA_Voided_Reason__c
            FROM Expressionofinterest__c WHERE Id = :lapsed.Expression_of_Interest__c
        ];
        System.assertEquals('Cancelled', closed.Status__c, 'A lapsed hold closes the EOI it raised');
        System.assert(closed.SLA_Voided_Reason__c != null && closed.SLA_Voided_Reason__c.contains('expired'),
            'The reason records what happened to the payment: ' + closed.SLA_Voided_Reason__c);

        Expressionofinterest__c untouched = [
            SELECT Status__c FROM Expressionofinterest__c WHERE Id = :kept.Expression_of_Interest__c
        ];
        System.assertNotEquals('Cancelled', untouched.Status__c,
            'An EOI whose payment was captured is left to the refund process, not cancelled here');
    }

    @IsTest
    static void aHoldThatLapsedOnItsOwnKeepsItsEoiButAnyOtherEndingClosesIt() {
        // Through a real update, so the trigger decides. A lapsed hold is recovered for a couple
        // of days before anyone gives up on it, so cancelling the EOI here would throw away a
        // deposit we can still take again. Every other ending is final and still closes it.
        useSeededUnidentifiedAccount();
        Checkout_Payment__c lapsing = newPayment('CKO-LAPSE-RECOVER', 'Authorized');
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ lapsing });
        Checkout_Payment__c ending = newPayment('CKO-LAPSE-FINAL', 'Authorized');
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ ending });

        Id recoverEoi = [SELECT Expression_of_Interest__c FROM Checkout_Payment__c
                         WHERE Id = :lapsing.Id].Expression_of_Interest__c;
        Id closeEoi   = [SELECT Expression_of_Interest__c FROM Checkout_Payment__c
                         WHERE Id = :ending.Id].Expression_of_Interest__c;

        Test.startTest();
        update new Checkout_Payment__c(Id = lapsing.Id,
            Status__c = EoiPaymentPolicy.STATUS_AUTHORIZATION_EXPIRED);
        update new Checkout_Payment__c(Id = ending.Id, Status__c = 'Voided');
        Test.stopTest();

        System.assertEquals(EoiPaymentPolicy.STATUS_PAYMENT_AUTHORIZED,
            [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :recoverEoi].Status__c,
            'A hold that ran out on its own leaves the EOI open so it can be recovered');
        System.assertEquals('Cancelled',
            [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :closeEoi].Status__c,
            'A voided hold is final, so it still closes the EOI');
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private static Checkout_Payment__c newPayment(String reference, String status) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = reference, Status__c = status, Amount__c = RANGE_AMOUNT, Currency_Code__c = 'AED',
            Payment_Id__c = 'pay_hold', EOI_Creation_Payload__c = buildPayload()
        );
        insert cp;
        return cp;
    }

    private static String buildPayload() {
        return JSON.serialize(new Map<String, Object>{
            'opportunityId' => oppId(), 'projectId' => projectId(), 'eoiRangeId' => rangeId(),
            'eoiAmount' => RANGE_AMOUNT, 'numberOfUnits' => 1,
            'paymentType' => 'Online', 'remarks' => 'hold unit test'
        });
    }

    /**
     * The unidentified finance account is org data, and org data is invisible to an @IsTest class
     * that does not use SeeAllData, so the builder would resolve to null and skip every receipt.
     * Point it at the account seeded by @TestSetup instead.
     */
    private static void useSeededUnidentifiedAccount() {
        EoiReceiptBuilder.accountIdOverride = seededAccountId();
    }

    private static Id seededAccountId() {
        return [SELECT Id FROM Account WHERE Name = 'EOI Hold Account' LIMIT 1].Id;
    }

    private static Id oppAccountId() {
        return [SELECT AccountId FROM Opportunity WHERE Id = :oppId()].AccountId;
    }

    private static Id oppId() {
        return [SELECT Id FROM Opportunity ORDER BY CreatedDate DESC LIMIT 1].Id;
    }

    private static Id projectId() {
        return [SELECT Id FROM Project__c WHERE Name = 'EOI Hold Project' LIMIT 1].Id;
    }

    private static Id rangeId() {
        return [SELECT Id FROM EOI_Range__c WHERE Project__c = :projectId() LIMIT 1].Id;
    }

    private static SObject createProject(String name) {
        SObject projectRecord = Schema.getGlobalDescribe().get('Project__c').newSObject();
        projectRecord.put('Name', name);
        insert projectRecord;
        return projectRecord;
    }

    private static SObject createRange(Id projId, Decimal amount) {
        SObject rangeRecord = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        putIfFieldExists(rangeRecord, 'Project__c', projId);
        putIfFieldExists(rangeRecord, 'Amount__c', amount);
        putIfFieldExists(rangeRecord, 'Is_Active__c', true);
        insert rangeRecord;
        return rangeRecord;
    }

    private static void putIfFieldExists(SObject rec, String f, Object v) {
        if (rec.getSObjectType().getDescribe().fields.getMap().containsKey(f.toLowerCase())) rec.put(f, v);
    }
}