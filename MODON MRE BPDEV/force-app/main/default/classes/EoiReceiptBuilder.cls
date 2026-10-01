/**********************************************************************************************
 * Name           : EoiReceiptBuilder
 * Description     : The one place an EOI payment Receipt__c is built. Books the receipt to the
 *                   unidentified finance account (label driven) rather than to the customer, and
 *                   flags it unidentified so finance approval can proceed without a Sales Order
 *                   (paymentApprovedController blocks a receipt with no SO unless the flag is set).
 *                   Returns unsaved records: the caller owns the DML, and therefore the transaction
 *                   shape, so a one-row-per-transaction caller and a bulk caller both work.
 *                   The EOI's own Account stays with the Opportunity - this class only ever
 *                   describes a receipt.
 * Usage           : CheckoutEoiMaterializer today. Broker Portal and the EOI microsite adopt this
 *                   builder instead of keeping their own copies of the same field map.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.2        Prateek Bansal    13 Sep 2026    Receipt carries the CKO reference, not the pay_ id.
 * 1.1        Prateek Bansal    10 Sep 2026    EntityName__c on the receipt, from the EOI's phase.
 *                                             Fusion resolves the remittance bank account from the
 *                                             entity, so a receipt without one is rejected with
 *                                             "You must provide a value for the
 *                                             RemittanceBankAccountNumber attribute".
 * 1.0        Prateek Bansal    10 Sep 2026    Initial version. Shared EOI receipt mapping,
 *                                             unidentified finance account, unidentified flag.
 **********************************************************************************************/
public without sharing class EoiReceiptBuilder {

    @TestVisible private static final String RECEIPT_TYPE_EOI  = 'EOI Receipt';
    @TestVisible private static final String MODE_ONLINE       = 'Online';
    @TestVisible private static final String STATUS_IN_PROGRESS = 'In Progress';

    /** Raised only to carry a reason into LoggerService; never thrown out of this class. */
    public class UnidentifiedAccountException extends Exception {}

    /**
     * Test seam. The unidentified account is org data, and org data is invisible to a test that
     * does not use SeeAllData, so resolve() would always return null under test and every receipt
     * would be skipped. Tests set this to an Account they created themselves.
     */
    @TestVisible private static Id accountIdOverride;

    /**
     * The unidentified finance account, or null when the label cannot be used. Resolve once per
     * transaction and pass the result to build(), so a bulk caller costs one query, not one each.
     *
     * Returns null rather than falling back to the customer's account: if the label is wrong,
     * skipping the receipt is recoverable, but booking a customer's money against their own record
     * is not. Callers are expected to log and carry on.
     */
    public static Id resolveUnidentifiedAccountId() {
        if (accountIdOverride != null) return accountIdOverride;

        String raw = System.Label.Unidentified_Account1;
        if (String.isBlank(raw)) return null;

        Id accountId;
        try {
            accountId = (Id) raw.trim();
        } catch (Exception e) {
            return null;                                  // label holds something that is not an Id
        }
        if (accountId.getSObjectType() != Account.SObjectType) return null;   // right shape, wrong object

        List<Account> rows = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
        return rows.isEmpty() ? null : rows[0].Id;        // Id is well formed but no such record here
    }

    /**
     * The phase entity behind each EOI, for the receipt's EntityName__c. One query for the whole
     * batch, so a bulk caller resolves once and passes each value into build().
     */
    public static Map<Id, String> entityNamesByEoi(Set<Id> eoiIds) {
        Map<Id, String> byEoi = new Map<Id, String>();
        if (eoiIds == null || eoiIds.isEmpty()) return byEoi;
        for (Expressionofinterest__c e : [
            SELECT Id, Phase__r.EntityName__c FROM Expressionofinterest__c WHERE Id IN :eoiIds
        ]) {
            byEoi.put(e.Id, e.Phase__r.EntityName__c);
        }
        return byEoi;
    }

    /**
     * One unsaved EOI receipt. unidentifiedAccountId must be non-null - Receipt__c.Account__c is a
     * required lookup, so a null here fails on insert rather than saving a headless receipt.
     *
     * entityName is the EOI phase's EntityName__c (see entityNamesByEoi). Fusion resolves the
     * remittance bank account from it, so a blank one comes back rejected. Left blank rather than
     * guessed when the phase has none: a wrong entity would book the money to the wrong company.
     */
    public static Receipt__c build(Id eoiId, Decimal amount, Checkout_Payment__c cp, Id unidentifiedAccountId, String entityName) {
        Receipt__c r = new Receipt__c(
            Account__c                   = unidentifiedAccountId,
            EntityName__c                = entityName,
            ExpressionOfInterest__c      = eoiId,
            TotalAmount__c               = amount,
            Receipt_Amount__c            = amount,
            Status__c                    = STATUS_IN_PROGRESS,
            Receipt_Type__c              = RECEIPT_TYPE_EOI,
            Modeofpayment__c             = MODE_ONLINE,
            Is_Un_Identified_Receipts__c = true,
            // The CKO reference, not the processor's pay_ id: it is what the Checkout statement and
            // the payment record both show, so finance can match the receipt to the money.
            TransactionNumber__c         = String.isNotBlank(cp.Reference__c) ? cp.Reference__c : cp.Payment_Id__c,
            TransactionDate__c           = System.now(),
            ReceiptDate__c               = System.today()
        );
        if (String.isNotBlank(cp.Currency_Code__c)) r.put('CurrencyIsoCode', cp.Currency_Code__c);
        return r;
    }
}