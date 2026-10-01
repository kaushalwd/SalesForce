/** Name              : CancellationContext
 * description        : Immutable data-transfer object that carries every Salesforce
                        record a cancellation strategy may need.  Loaded once by
                        SRCancellationExecutor; passed by reference to strategies and
                        shared services so there is exactly one SOQL round-trip per execution              
 *Created By          : Active Minds
 *********************************************************************************
*  Version  Author          Date        Notes
** 1.0      Manoj           15 Mar 2026    Initial
**********************************************************************************/
public class CancellationContext {

  // ─── Service Request ─────────────────────────────────────────────────────
    // `private set` prevents external mutation; `final` is intentionally omitted
    // because Apex only allows final assignment inside constructors, not via
    // the property setter syntax used here.
 
    public ServiceRequest__c sr               { get; private set; }
    public String            cancellationType { get; private set; }
 
    // ─── Sales Order ──────────────────────────────────────────────────────────
 
    public Id salesOrderId    { get; private set; }
    public Id unitId          { get; private set; }
    public Id customerAccount { get; private set; }
 
    // ─── Child records ────────────────────────────────────────────────────────
 
    public List<Invoice__c>                invoices     { get; private set; }
    public List<Receipt__c>               receipts     { get; private set; }
    public List<SalesOrderInstallments__c> installments { get; private set; }
 
    // ─── All-args private constructor ────────────────────────────────────────
    // Apex `final` fields must be set inside the constructor body.
    // All eight fields are set here so the compiler is satisfied and the
    // object is fully initialised in one step.
 
    private CancellationContext(
        ServiceRequest__c               sr,
        String                          cancellationType,
        Id                              salesOrderId,
        Id                              unitId,
        Id                              customerAccount,
        List<SalesOrderInstallments__c> installments,
        List<Invoice__c>               invoices,
        List<Receipt__c>               receipts
    ) {
        this.sr               = sr;
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
     * @description Loads all required records for the given Service Request Id
     *              and returns a fully populated, immutable context.
     * @param srId  Id of the ServiceRequest__c record.
     * @throws AuraHandledException when the SR or its SalesOrder cannot be found.
     */
    public static CancellationContext build(Id srId) {
 
        List<ServiceRequest__c> srList = [
            SELECT Id,
                   Cancellation_Type__c,
                   Refund_Amount__c,
                   Forfeiture_Amount__c,
                   Total_Paid_Amount__c,
                   Payable_to_Customer__c,
                   Equity_Transfer_Amount__c,
                   Forfeiture__c,
                   Management_Fee__c,
                   RecordTypeName__c,
                   SalesOrder__c,
                   SalesOrder__r.Unit__c,
                   SalesOrder__r.CustomerAccount__c,ADM_ADGM_Refund_Amount__c,Is_ADM_Refund_Needed__c
            FROM ServiceRequest__c
            WHERE Id = :srId
            LIMIT 1
        ];
 
        if (srList.isEmpty() || srList[0].SalesOrder__c == null) {
            throw new AuraHandledException(
                'Invalid Service Request: record not found or missing Sales Order.');
        }
 
        ServiceRequest__c sr = srList[0];
        Id soId              = sr.SalesOrder__c;
        Boolean isAdmRefund = sr.Is_ADM_Refund_Needed__c == 'Yes';

 
        // ── Installments ─────────────────────────────────────────────────────
        List<SalesOrderInstallments__c> installments = [
            SELECT Id
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :soId
        ];
        
        // ── Invoices (non-cancelled, linked to installments) ─────────────────
        List<Invoice__c> invoices =new List<Invoice__c>();
            //if(isAdmRefund){
            	invoices = [ select Id, InvoiceStatus__c, isCancelled__c, OraclePartyId__c,Account__c,Sales_Order__c,SalesOrderInstallment__c,Is_ADM_Fees_and_Dari_charges__c,AppliedAmount__c,Charge__c,Description__c,InvoiceAmount__c, InvoiceDate__c,TotalPaidAmount__c FROM Invoice__c WHERE InvoiceStatus__c NOT IN ('Cancelled') and (SalesOrderInstallment__r.SalesOrder__c  =: soId OR Sales_Order__c =:soId ) ];
            /*}else {
        		invoices = [ select Id, InvoiceStatus__c, isCancelled__c, OraclePartyId__c,Account__c,Sales_Order__c,SalesOrderInstallment__c,Is_ADM_Fees_and_Dari_charges__c,AppliedAmount__c,Charge__c,Description__c,InvoiceAmount__c, InvoiceDate__c,TotalPaidAmount__c FROM Invoice__c WHERE InvoiceStatus__c NOT IN ('Cancelled') and (SalesOrderInstallment__r.SalesOrder__c  =: soId ) ];
            }*/
        // ── Receipts (all statuses – cancel logic decides what to skip) ───────
        List<Receipt__c> receipts = [
            SELECT Id, Status__c, OraclePartyId__c, TotalAmount__c,Receipt_Excess_Amount__c,
                   Account__c, SalesOrder__c, SalesOrderInstallment__c,Oracle_Id_Temporary__c
            FROM Receipt__c
            WHERE SalesOrder__c = :soId
        ];
 
        return new CancellationContext(
            sr,
            sr.Cancellation_Type__c,
            soId,
            sr.SalesOrder__r.Unit__c,
            sr.SalesOrder__r.CustomerAccount__c,
            installments,
            invoices,
            receipts
        );
    }
}