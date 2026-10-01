/**********************************************************************************************
 * Name           : EoiReceiptBuilderTest
 * Description     : Covers the shared EOI receipt builder. The behaviour that matters here is the
 *                   account the receipt is booked to and the unidentified flag, because
 *                   paymentApprovedController refuses a receipt with no Sales Order unless that
 *                   flag is set.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.2        Prateek Bansal    13 Sep 2026    Receipt carries the CKO reference, so assert that.
 * 1.1        Prateek Bansal    10 Sep 2026    EntityName__c: carried onto the receipt, and resolved
 *                                             from the EOI's phase by entityNamesByEoi.
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version.
 **********************************************************************************************/
@IsTest
private class EoiReceiptBuilderTest {

    // A live value of BOTH picklists: Phase__c.EntityName__c and Receipt__c.EntityName__c hold the
    // same six entries, which is what lets the phase's value be copied straight onto the receipt.
    private static final String ENTITY = 'Modon Properties PJSC';

    private static Checkout_Payment__c payment(String paymentId, String reference) {
        return new Checkout_Payment__c(
            Reference__c    = reference,
            Payment_Id__c   = paymentId,
            Status__c       = 'Captured',
            Currency_Code__c = 'AED'
        );
    }

    @IsTest
    static void buildBooksToTheUnidentifiedAccountAndFlagsIt() {
        Account unidentified = new Account(Name = 'Unidentified Account (MRE Finance) - test');
        insert unidentified;

        Test.startTest();
        Receipt__c r = EoiReceiptBuilder.build(null, 5000, payment('pay_123', 'CKO-REF-1'), unidentified.Id, ENTITY);
        Test.stopTest();

        System.assertEquals(unidentified.Id, r.Account__c, 'receipt books to the unidentified account, not the customer');
        System.assertEquals(true, r.Is_Un_Identified_Receipts__c, 'flag must be set or finance approval is blocked');
        System.assertEquals(ENTITY, r.EntityName__c, 'Fusion resolves the remittance bank from the entity');
        System.assertEquals('EOI Receipt', r.Receipt_Type__c, 'receipt type');
        System.assertEquals('Online', r.Modeofpayment__c, 'mode of payment');
        System.assertEquals('In Progress', r.Status__c, 'initial status');
        System.assertEquals(5000, r.TotalAmount__c, 'total amount');
        System.assertEquals(5000, r.Receipt_Amount__c, 'receipt amount');
        System.assertEquals(null, r.Id, 'builder returns an unsaved record so the caller owns the DML');
    }

    @IsTest
    static void transactionNumberPrefersReferenceAndFallsBackToPaymentId() {
        Account unidentified = new Account(Name = 'Unidentified Account (MRE Finance) - test');
        insert unidentified;

        Receipt__c withBoth = EoiReceiptBuilder.build(null, 100, payment('pay_abc', 'CKO-REF-2'), unidentified.Id, ENTITY);
        Receipt__c referenceOnly = EoiReceiptBuilder.build(null, 100, payment(null, 'CKO-REF-3'), unidentified.Id, ENTITY);
        Receipt__c paymentIdOnly = EoiReceiptBuilder.build(null, 100, payment('pay_xyz', null), unidentified.Id, ENTITY);

        System.assertEquals('CKO-REF-2', withBoth.TransactionNumber__c, 'the CKO reference wins when present');
        System.assertEquals('CKO-REF-3', referenceOnly.TransactionNumber__c, 'reference alone is used');
        System.assertEquals('pay_xyz', paymentIdOnly.TransactionNumber__c, 'the payment id is the fallback');
    }

    @IsTest
    static void resolveReturnsTheAccountWhenTheLabelPointsAtARealOne() {
        // The label is org configuration, so this asserts on the live value rather than setting it:
        // either it resolves to an Account, or it is null and the caller is expected to skip.
        Test.startTest();
        Id resolved = EoiReceiptBuilder.resolveUnidentifiedAccountId();
        Test.stopTest();

        if (resolved != null) {
            System.assertEquals(
                Account.SObjectType, resolved.getSObjectType(),
                'the label must resolve to an Account, never another object'
            );
            System.assertEquals(
                1, [SELECT COUNT() FROM Account WHERE Id = :resolved],
                'a resolved id must be a record that actually exists'
            );
        }
    }

    @IsTest
    static void aResolvedAccountProducesAnInsertableReceipt() {
        // Account__c is a required lookup, so the whole point of resolving first is that the
        // insert succeeds. This proves the built record is actually saveable.
        Account unidentified = new Account(Name = 'Unidentified Account (MRE Finance) - test');
        insert unidentified;

        Receipt__c r = EoiReceiptBuilder.build(null, 250, payment('pay_ins', 'CKO-REF-4'), unidentified.Id, ENTITY);

        Test.startTest();
        insert r;
        Test.stopTest();

        Receipt__c saved = [
            SELECT Account__c, Is_Un_Identified_Receipts__c, Receipt_Type__c, EntityName__c
            FROM Receipt__c WHERE Id = :r.Id
        ];
        System.assertEquals(unidentified.Id, saved.Account__c, 'saved against the unidentified account');
        System.assertEquals(true, saved.Is_Un_Identified_Receipts__c, 'flag survives the insert');
        System.assertEquals(ENTITY, saved.EntityName__c, 'the entity must survive the insert, or Fusion rejects the receipt');
    }

    @IsTest
    static void entityNamesComeFromTheEoiPhase() {
        // The whole point of the resolver: one query for the batch, and the value it returns is the
        // phase's, not a guess. A phase with no entity must come back null rather than defaulted.
        Account acc = new Account(Name = 'Entity Resolver Account');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'Entity Resolver Opp', StageName = 'Discussion In Progress',
            CloseDate = Date.today().addDays(10), AccountId = acc.Id
        );
        insert opp;

        Phase__c withEntity = new Phase__c(Name = 'Entity Phase', EntityName__c = ENTITY);
        Phase__c withoutEntity = new Phase__c(Name = 'Blank Phase');
        insert new List<Phase__c>{ withEntity, withoutEntity };

        Expressionofinterest__c a = new Expressionofinterest__c(Opportunity__c = opp.Id, Phase__c = withEntity.Id);
        Expressionofinterest__c b = new Expressionofinterest__c(Opportunity__c = opp.Id, Phase__c = withoutEntity.Id);
        insert new List<Expressionofinterest__c>{ a, b };

        Test.startTest();
        Map<Id, String> byEoi = EoiReceiptBuilder.entityNamesByEoi(new Set<Id>{ a.Id, b.Id });
        Test.stopTest();

        System.assertEquals(ENTITY, byEoi.get(a.Id), 'the phase entity is carried through');
        System.assertEquals(null, byEoi.get(b.Id), 'a phase with no entity resolves to null, never a default');
        System.assertEquals(
            true, EoiReceiptBuilder.entityNamesByEoi(new Set<Id>()).isEmpty(),
            'an empty input must not cost a query'
        );
    }
}