/** Name              : BPCancellationContext
 * description        : Immutable data-transfer object that carries every Salesforce
 *                      record a Business_Process__c cancellation strategy may need.
 *                      Loaded once by BPCancellationExecutor; passed by reference to
 *                      strategies and shared services so there is exactly one SOQL
 *                      round-trip per execution.
 *Created By          : Active Minds
**********************************************************************************/
public class BPCancellationContext {

    // ─── Business Process ─────────────────────────────────────────────────────

    public Business_Process__c bp               { get; private set; }
    public String              cancellationType { get; private set; }

    // ─── Sales Order ──────────────────────────────────────────────────────────

    public Id salesOrderId    { get; private set; }
    public Id unitId          { get; private set; }
    public Id customerAccount { get; private set; }

    // ─── Child records ────────────────────────────────────────────────────────

    public List<Invoice__c>                invoices     { get; private set; }
    public List<Receipt__c>                receipts     { get; private set; }
    public List<SalesOrderInstallments__c> installments { get; private set; }

    // ─── All-args private constructor ────────────────────────────────────────

    private BPCancellationContext(
        Business_Process__c             bp,
        String                          cancellationType,
        Id                              salesOrderId,
        Id                              unitId,
        Id                              customerAccount,
        List<SalesOrderInstallments__c> installments,
        List<Invoice__c>                invoices,
        List<Receipt__c>                receipts
    ) {
        this.bp               = bp;
        this.cancellationType = cancellationType;
        this.salesOrderId     = salesOrderId;
        this.unitId           = unitId;
        this.customerAccount  = customerAccount;
        this.installments     = installments;
        this.invoices         = invoices;
        this.receipts         = receipts;
    }

    // ─── Factory ─────────────────────────────────────────────────────────────

    /**
     * @description Loads all required records for the given Business_Process__c Id
     *              and returns a fully populated, immutable context.
     * @param bpId  Id of the Business_Process__c record.
     * @throws AuraHandledException when the BP or its SalesOrder cannot be found.
     */
    public static BPCancellationContext build(Id bpId) {

        List<Business_Process__c> bpList = [
            SELECT Id, Cancellation_Type__c, Refund_Amount__c, Forfeiture_Amount__c, Total_Paid_Amount__c,
                   Payable_to_Customer__c,Equity_Transfer_Amount__c,Management_Fee__c, Type__c,
                   Sales_Order__c, Sales_Order__r.Unit__c, Sales_Order__r.CustomerAccount__c, ADM_ADGM_Refund_Amount__c,
                   ADM_Paid_Amount__c, Down_Payment_Amount__c, Is_ADM_Refund_Needed__c
            FROM Business_Process__c
            WHERE Id = :bpId
            LIMIT 1
        ];

        if (bpList.isEmpty() || bpList[0].Sales_Order__c == null) {
            throw new AuraHandledException(
                'Invalid Business Process: record not found or missing Sales Order.');
        }

        Business_Process__c bp = bpList[0];
        Id soId                = bp.Sales_Order__c;

        // ── Installments ─────────────────────────────────────────────────────
        List<SalesOrderInstallments__c> installments = [
            SELECT Id
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :soId
        ];

        // ── Invoices (non-cancelled, linked to installments) ─────────────────
        List<Invoice__c> invoices = [
            SELECT Id, InvoiceStatus__c, isCancelled__c, OraclePartyId__c, Account__c,
                   Sales_Order__c, SalesOrderInstallment__c, Is_ADM_Fees_and_Dari_charges__c,
                   AppliedAmount__c, Charge__c, Description__c, InvoiceAmount__c,
                   InvoiceDate__c, TotalPaidAmount__c
            FROM Invoice__c
            WHERE InvoiceStatus__c NOT IN ('Cancelled')
              AND (SalesOrderInstallment__r.SalesOrder__c = :soId OR Sales_Order__c = :soId)
        ];

        // ── Receipts (all statuses – cancel logic decides what to skip) ───────
        List<Receipt__c> receipts = [
            SELECT Id, Status__c, OraclePartyId__c, TotalAmount__c, Receipt_Excess_Amount__c,
                   Account__c, SalesOrder__c, SalesOrderInstallment__c, Oracle_Id_Temporary__c
            FROM Receipt__c
            WHERE SalesOrder__c = :soId
        ];

        return new BPCancellationContext(
            bp,
            bp.Cancellation_Type__c,
            soId,
            bp.Sales_Order__r.Unit__c,
            bp.Sales_Order__r.CustomerAccount__c,
            installments,
            invoices,
            receipts
        );
    }
}