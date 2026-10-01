/**********************************************************************************************************************
* Name               : InvoiceSelector
* Description        : Selector class for Invoice__c. Centralizes SOQL used by the Oracle-Salesforce integration.
*                      Fields are grouped object-wise and the final query is built dynamically and executed with
*                      Database.query.
* Created By         : PWC Digital Middle East
***********************************************************************************************************************/
public class InvoiceSelector {

    // Base Invoice__c fields
    private static final String INVOICE_FIELDS =
          'Id, Name, InvoiceAmount__c, Ebs_Invoice_Date__c, InvoiceDate__c, InvoiceStatus__c, Account__c, '
        + 'Sales_Order__c, SalesOrderInstallment__c, Actual_Invoice_Amount__c, OraclePartyId__c, '
        + 'Parent_Invoice__c, RefundOracleid__c, Status__c, RecordType.name, Transaction_Type__c, Invoice_Number__c, Invoice_Advance__r.Parent_Invoice__c';

    // Account (customer) fields
    private static final String ACCOUNT_FIELDS = 'Account__r.OraclePartyId__c, Account__r.Bank_Account_Number__c, Account__r.IBAN_Number__c, '
        + 'Account__r.Swift_Code__c, Account__r.Bank_Name__c, Account__r.Beneficiary_Name__c';

    // Parent Invoice fields
    private static final String PARENT_INVOICE_FIELDS = 'Parent_Invoice__r.OraclePartyId__c';

    // Charge fields
    private static final String CHARGE_FIELDS = 'Charge__r.Type__c';

    // Sales Order fields (incl. Unit / Phase / Virtual Account / Escrow)
    private static final String SALES_ORDER_FIELDS =
          'Sales_Order__r.Name, Sales_Order__r.NotToBeShownOnRD__c, Sales_Order__r.Source_Entity__c, '
        + 'Sales_Order__r.CustAcctId__c, Sales_Order__r.OraclePartySiteID__c, Sales_Order__r.OracleCustAcctSiteID__c, '
        + 'Sales_Order__r.OracleSiteUseID__c, Sales_Order__r.Unit__c, Sales_Order__r.Unit__r.Name, '
        + 'Sales_Order__r.Unit__r.PlotNo__c, Sales_Order__r.Unit__r.Project_Name__c, Sales_Order__r.Unit__r.UnitClassification__c, '
        + 'Sales_Order__r.Unit__r.Phase__r.Name, Sales_Order__r.Unit__r.Phase__r.EntityName__c, '
        + 'Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c, Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c, '
        + 'Sales_Order__r.VirtualAccount__r.Name, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c, '
        + 'Sales_Order__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.StoreId__c, '
        + 'Sales_Order__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.TradeID__c, '
        + 'Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BankName__c, Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c';

    // Sales Order Installment fields (incl. nested Sales Order / Unit / Phase / Virtual Account / Escrow)
    private static final String SALES_ORDER_INSTALLMENT_FIELDS =
          'SalesOrderInstallment__r.Name, SalesOrderInstallment__r.MilestoneDescription__c, SalesOrderInstallment__r.Milestone_Name__c, '
        + 'SalesOrderInstallment__r.SalesOrder__c, SalesOrderInstallment__r.SalesOrder__r.Name, SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c, SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c, SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c, SalesOrderInstallment__r.SalesOrder__r.Unit__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Name, SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c, SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.StoreId__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c, SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.TradeID__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c, SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c';

    // Advance Tax Invoice fields (the invoice itself and its source Invoice; the Allocation/Receipt are
    // resolved separately from the source Invoice via AllocationSelector)
    private static final String ADVANCE_TAX_INVOICE_FIELDS =
          'Id, Name, InvoiceAmount__c, InvoiceDate__c, Ebs_Invoice_Date__c, InvoiceStatus__c, Account__c, '
        + 'Sales_Order__c, SalesOrderInstallment__c, OraclePartyId__c, Transaction_Type__c, IsCancelled__c, Invoice_Number__c, '
        + 'Invoice_Advance__c, Invoice_Advance__r.Name, Invoice_Advance__r.Parent_Invoice__c';
    /**
     * Description : Returns Invoice__c records for the given Ids that are either not yet synced to Oracle
     *               (OraclePartyId__c = null) or have been cancelled. Fields are assembled object-wise and
     *               the query is executed with Database.query.
     */
    public static List<Invoice__c> getInvoicesByIds(Set<String> installmentIds) {
        //Combined field list
        String FIELD_LIST = String.join(new List<String>{
            INVOICE_FIELDS, ACCOUNT_FIELDS, PARENT_INVOICE_FIELDS, CHARGE_FIELDS, SALES_ORDER_FIELDS, SALES_ORDER_INSTALLMENT_FIELDS
        }, ', ');

        String query = 'SELECT ' + FIELD_LIST
                     + ' FROM Invoice__c'
                     + ' WHERE Id IN :installmentIds'
                     + ' AND (OraclePartyId__c = null OR InvoiceStatus__c = \'Cancelled\')';
        System.debug('Print Query '+ query);

        return (List<Invoice__c>) Database.query(query);
    }
    
    public static List<Invoice__c> getInvoicesByIdsOracleId(Set<String> installmentIds) {
        //Combined field list
        String FIELD_LIST = String.join(new List<String>{
            INVOICE_FIELDS, ACCOUNT_FIELDS, PARENT_INVOICE_FIELDS, CHARGE_FIELDS, SALES_ORDER_FIELDS, SALES_ORDER_INSTALLMENT_FIELDS
        }, ', ');

        String query = 'SELECT ' + FIELD_LIST
                     + ' FROM Invoice__c'
                     + ' WHERE Id IN :installmentIds'
                     + ' AND OraclePartyId__c != null';
        System.debug('Print Query '+ query);

       return (List<Invoice__c>) Database.query(query);
    }
    
    /**
     * Description : Returns Advance Tax Invoice__c records (Transaction_Type__c = 'Advance Tax') for the given
     *               Ids that are either not yet synced to Oracle (OraclePartyId__c = null) or have been cancelled.
     */
    public static List<Invoice__c> getAdvanceTaxInvoicesByIds(Set<String> invoiceIds) {
        String FIELD_LIST = String.join(new List<String>{
            ADVANCE_TAX_INVOICE_FIELDS, ACCOUNT_FIELDS, SALES_ORDER_FIELDS, SALES_ORDER_INSTALLMENT_FIELDS
        }, ', ');

        String query = 'SELECT ' + FIELD_LIST
                     + ' FROM Invoice__c'
                     + ' WHERE Id IN :invoiceIds'
                     + ' AND Transaction_Type__c = \'Advance Tax\''
                     + ' AND OraclePartyId__c = null';
        System.debug('Print Query '+ query);

        return (List<Invoice__c>) Database.query(query);
    }

    /**
     * Description : Returns the Advance Tax Invoice__c records raised against the supplied installment
     *               Invoices (Invoice_Advance__c) that are already synced to Oracle (OraclePartyId__c != null)
     *               and not yet cancelled. These must be cancelled in Oracle before their source installment
     *               can be re-sent.
     * @param installmentIds Ids of the installment Invoices being processed by createInstallment.
     */
    public static List<Invoice__c> getAdvanceTaxInvoicesToCancel(Set<String> installmentIds) {
        if (installmentIds == null || installmentIds.isEmpty()) return new List<Invoice__c>();

        String FIELD_LIST = String.join(new List<String>{
            ADVANCE_TAX_INVOICE_FIELDS, ACCOUNT_FIELDS, SALES_ORDER_FIELDS
        }, ', ');

        String query = 'SELECT ' + FIELD_LIST
                     + ' FROM Invoice__c'
                     + ' WHERE Invoice_Advance__c IN :installmentIds'
                     + ' AND Transaction_Type__c = \'Advance Tax\''
                     //+ ' AND OraclePartyId__c != null'
                     + ' AND IsCancelled__c = false';
        System.debug('Print Query '+ query);

        return (List<Invoice__c>) Database.queryWithBinds(
            query,
            new Map<String, Object>{ 'installmentIds' => installmentIds },
            AccessLevel.SYSTEM_MODE
        );
    }
}