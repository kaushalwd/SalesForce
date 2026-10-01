/**********************************************************************************************************************
* Name               : ReceiptSelector
* Description        : Selector class for the Receipt__c object. Centralizes SOQL queries used by the
*                      Oracle-Salesforce (Fusion) integration classes.
* Usage              : Called from OIC_ManageSalesforceDataController and related integration classes.
* Created By         : MODON IT
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           MODON IT     				26 Jul 2026     Initial Draft - extracted createReceipt SOQL
***********************************************************************************************************************/
public class ReceiptSelector {

    //Base Receipt__c fields
    private static final String BASE_FIELDS =
          'Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, '
        + 'TransactionDate__c, TransactionNumber__c, ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, ChequeDate__c, '
        + 'TotalAmount__c, Bank__c, Status__c, Milestone_Description__c, EBS_Clearing_Date__c, Cheque_Number__c, '
        + 'Cheque_Bounce_Reason__c, Reason_Code__c, OraclePartyId__c, isReverseEBS__c, Transaction_Type__c, Is_ADM_Fees_And_Dari_charges__c, '
        + 'RecordType.name';

    //Account (customer) fields 
    private static final String ACCOUNT_FIELDS = 'Account__r.OraclePartyId__c, Account__r.Bank_Account_Number__c, Account__r.IBAN_Number__c, '
        + 'Account__r.Swift_Code__c, Account__r.Bank_Name__c, Account__r.Beneficiary_Name__c';

    // Charge fields
    private static final String CHARGE_FIELDS = 'Charge__r.Type__c';

    // Payment Escrow Account fields
    private static final String ESCROW_FIELDS =
          'PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, '
        + 'PaymentEscrowAccount__r.IBANNo__c, PaymentEscrowAccount__r.Name';

    // SalesOrder (direct) fields
    private static final String SALES_ORDER_FIELDS =
          'SalesOrder__r.ProjectName__c, SalesOrder__r.Name, SalesOrder__r.Unit__c, SalesOrder__r.Unit__r.Name, '
        + 'SalesOrder__r.Unit__r.Project_Name__c, SalesOrder__r.Unit__r.UnitClassification__c, '
        + 'SalesOrder__r.Unit__r.Phase__r.Name, SalesOrder__r.Unit__r.Phase__r.EntityName__c, '
        + 'SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, '
        + 'SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, SalesOrder__r.OracleCustAcctSiteID__c, '
        + 'SalesOrder__r.OracleSiteUseID__c, SalesOrder__r.NotToBeShownOnRD__c';

    //SalesOrderInstallment fields
    private static final String SALES_ORDER_INSTALLMENT_FIELDS =
          'SalesOrderInstallment__r.Name, SalesOrderInstallment__r.Milestone_Name__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, SalesOrderInstallment__r.SalesOrder__r.Name, '
        + 'SalesOrderInstallment__r.SalesOrder__r.Unit__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name, '
        + 'SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c, '
        + 'SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c';

    /**
     * Description : Returns the list of Receipt__c records eligible for the Fusion receipt callout,
     *               filtered by the supplied receipt Ids. The field list, object, and WHERE clause are
     *               declared as reusable class-level String constants, then combined and executed via
     *               Database.query.
     * @param receiptIds Set of Receipt__c Ids to query.
     * @return List<Receipt__c> matching the integration eligibility criteria.
     */
    public static List<Receipt__c> getReceiptsById(Set<String> receiptIds) {

        //Combined field list
        String FIELD_LIST = String.join(new List<String>{
            BASE_FIELDS, ACCOUNT_FIELDS, CHARGE_FIELDS, ESCROW_FIELDS, SALES_ORDER_FIELDS, SALES_ORDER_INSTALLMENT_FIELDS
        }, ', ');

        //Object and filter clauses
        String OBJECT_NAME = 'Receipt__c';
        String WHERE_CLAUSE =
              'Id IN :receiptIds '
            + 'AND Oracle_Id_Temporary__c = null '
            + 'AND Account__r.OraclePartyId__c != null '
            + 'AND SalesOrder__r.OraclePartySiteID__c != null '
            + 'AND SalesOrder__r.NotToBeShownOnRD__c = false '
            + 'AND SalesOrder__r.Source_Entity__c != \'Modon - Egypt\'';

        //Build and execute the dynamic query
        String queryString = 'SELECT ' + FIELD_LIST + ' FROM ' + OBJECT_NAME + ' WHERE ' + WHERE_CLAUSE;

        return (List<Receipt__c>) Database.query(queryString);
    }
}