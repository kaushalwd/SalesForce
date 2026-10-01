/**********************************************************************************************
 * Name           : CheckoutMaterializeQueueableTest
 * Description     : Coverage for the batch hand-over chain, which is where a lapsed hold is really
 *                   closed. CheckoutPaymentTrigger runs its EOI cascade only outside batch context,
 *                   and the poller is a batch - so the poller's finish() enqueues this queueable and
 *                   it, not the trigger, decides the fate of an EOI whose hold ran out. A guard that
 *                   lives only in the trigger therefore does nothing on the path that actually runs.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    21 Sep 2026    Initial version. A hold in recovery survives the chain.
 **********************************************************************************************/
@IsTest
private class CheckoutMaterializeQueueableTest {

    private static final Decimal RANGE_AMOUNT = 650000;

    @TestSetup
    static void seed() {
        Account acc = new Account(Name = 'MQ Account', Phone = '+971500000000');
        insert acc;
        Contact con = new Contact(
            AccountId = acc.Id, FirstName = 'MQ', LastName = 'Contact',
            Email = 'mq.contact@example.com', MobilePhone = '+971500000001'
        );
        insert con;
        Opportunity opp = new Opportunity(
            Name = 'MQ Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        putIfFieldExists(opp, 'ContactId', con.Id);
        insert opp;

        SObject project = createProject('MQ Project');
        createRange((Id) project.get('Id'), RANGE_AMOUNT);
    }

    /**
     * The regression this class exists for. Both rows are staged at their lapsed status on INSERT,
     * where the trigger's cascade never runs (it is update-only), so runOne is the only actor and
     * the assertions are about the batch path alone.
     */
    @IsTest
    static void aHoldInRecoveryKeepsItsEoiWhileAVoidedOneStillCloses() {
        useSeededUnidentifiedAccount();
        Id recoveringEoi = eoiRaisedOn('CKO-MQ-SEED-RECOVER');
        Id endedEoi      = eoiRaisedOn('CKO-MQ-SEED-VOID');

        lapsedRowOn('CKO-MQ-RECOVER', EoiPaymentPolicy.STATUS_AUTHORIZATION_EXPIRED, recoveringEoi);
        lapsedRowOn('CKO-MQ-VOID', 'Voided', endedEoi);

        Test.startTest();
        CheckoutMaterializeQueueable.runOne(7);
        Test.stopTest();

        System.assertEquals(EoiPaymentPolicy.STATUS_PAYMENT_AUTHORIZED,
            [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :recoveringEoi].Status__c,
            'A hold that ran out on its own is still being retried, so the batch chain must leave its EOI open');
        System.assertEquals('Cancelled',
            [SELECT Status__c FROM Expressionofinterest__c WHERE Id = :endedEoi].Status__c,
            'A voided hold is final, so the batch chain still closes its EOI');
    }

    /** A row in recovery must not fall through the close branch into the receipt branch instead. */
    @IsTest
    static void aHoldInRecoveryIsNeverReceiptedEither() {
        useSeededUnidentifiedAccount();
        Id recoveringEoi = eoiRaisedOn('CKO-MQ-SEED-NORECEIPT');
        lapsedRowOn('CKO-MQ-NORECEIPT', EoiPaymentPolicy.STATUS_AUTHORIZATION_EXPIRED, recoveringEoi);

        Test.startTest();
        Boolean moreLeft = CheckoutMaterializeQueueable.runOne(7);
        Test.stopTest();

        System.assertEquals(false, moreLeft,
            'Nothing is left to do: a hold in recovery is not a candidate at all, so the chain stops');
        System.assertEquals(0, [SELECT COUNT() FROM Receipt__c WHERE ExpressionOfInterest__c = :recoveringEoi],
            'No money was taken, so nothing may be receipted');
    }

    /** The set the trigger and the batch chain both read. Stated once so the two can never drift. */
    @IsTest
    static void onlyAFinalLapseClosesAnEoi() {
        System.assertEquals(false,
            EoiPaymentPolicy.CLOSING_LAPSED_STATUSES.contains(EoiPaymentPolicy.STATUS_AUTHORIZATION_EXPIRED),
            'A hold that ran out on its own is recovered, not closed');
        for (String finalLapse : new List<String>{ 'Expired', 'Voided', 'Declined' }) {
            System.assertEquals(true, EoiPaymentPolicy.CLOSING_LAPSED_STATUSES.contains(finalLapse),
                finalLapse + ' ends the payment for good and still closes the EOI');
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    /** A held payment materialised into a real EOI, returning that EOI. */
    private static Id eoiRaisedOn(String reference) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Authorized', Amount__c = RANGE_AMOUNT,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_mq', EOI_Creation_Payload__c = buildPayload()
        );
        insert cp;
        CheckoutEoiMaterializer.materialize(new List<Checkout_Payment__c>{ cp });
        return [SELECT Expression_of_Interest__c FROM Checkout_Payment__c WHERE Id = :cp.Id]
            .Expression_of_Interest__c;
    }

    /** The row runOne is asked about, inserted straight at its lapsed status so no trigger acts. */
    private static Checkout_Payment__c lapsedRowOn(String reference, String status, Id eoiId) {
        Checkout_Payment__c cp = new Checkout_Payment__c(
            Reference__c = reference, Status__c = status, Amount__c = RANGE_AMOUNT,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_mq', EOI_Creation_Payload__c = buildPayload(),
            Expression_of_Interest__c = eoiId
        );
        insert cp;
        return cp;
    }

    private static String buildPayload() {
        return JSON.serialize(new Map<String, Object>{
            'opportunityId' => oppId(), 'projectId' => projectId(), 'eoiRangeId' => rangeId(),
            'eoiAmount' => RANGE_AMOUNT, 'numberOfUnits' => 1,
            'paymentType' => 'Online', 'remarks' => 'materialize chain unit test'
        });
    }

    /** Org data is invisible to an @IsTest class, so point the builder at the seeded account. */
    private static void useSeededUnidentifiedAccount() {
        EoiReceiptBuilder.accountIdOverride = [SELECT Id FROM Account WHERE Name = 'MQ Account' LIMIT 1].Id;
    }

    private static Id oppId() {
        return [SELECT Id FROM Opportunity ORDER BY CreatedDate DESC LIMIT 1].Id;
    }

    private static Id projectId() {
        return [SELECT Id FROM Project__c WHERE Name = 'MQ Project' LIMIT 1].Id;
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