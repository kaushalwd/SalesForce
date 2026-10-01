global class ReceiptEBSIntegrationBatch implements Database.Batchable<SObject>,Schedulable, Database.AllowsCallouts {

    private final String projectName = null;
    private final String phaseName = null;
	private final set<String> ReciptIds;
    // Constructor
    public ReceiptEBSIntegrationBatch(String projectName, String phaseName,set<string> ReciptIds) {
        this.projectName = projectName;
        this.phaseName = phaseName;
        this.ReciptIds = ReciptIds;
    }
	
   
    // start 
    global Database.QueryLocator start(Database.BatchableContext bc) {
        if(ReciptIds != null){
            if(projectName != null && phaseName != null){
                return Database.getQueryLocator([
                    SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, 
                           SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, 
                           SalesOrder__r.ProjectName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                           PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, 
                           TransactionDate__c, PaymentEscrowAccount__r.IBANNo__c, 
                           PaymentEscrowAccount__r.Name, TransactionNumber__c, 
                           ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, 
                           ChequeDate__c, TotalAmount__c, Bank__c, Status__c, 
                           SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                           SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c, 
                           SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, 
                           SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, 
                           SalesOrder__r.OracleCustAcctSiteID__c, 
                           SalesOrder__r.OracleSiteUseID__c, 
                           SalesOrder__r.NotToBeShownOnRD__c 
                    FROM Receipt__c 
                    WHERE Oracle_Id_Temporary__c = null 
                    AND Account__r.OraclePartyId__c != null 
                    AND SalesOrder__r.OraclePartySiteID__c != null 
                    AND SalesOrder__r.NotToBeShownOnRD__c = false 
                    AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                    AND SalesOrder__r.ProjectName__c = :projectName 
                    AND SalesOrder__r.Unit__r.Phase__r.Name = :phaseName
                    AND Id IN :ReciptIds
                ]);
            } else if(projectName != null && phaseName == null){
                return Database.getQueryLocator([
                    SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, 
                           SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, 
                           SalesOrder__r.ProjectName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                           PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, 
                           TransactionDate__c, PaymentEscrowAccount__r.IBANNo__c, 
                           PaymentEscrowAccount__r.Name, TransactionNumber__c, 
                           ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, 
                           ChequeDate__c, TotalAmount__c, Bank__c, Status__c, 
                           SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                           SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c, 
                           SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, 
                           SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, 
                           SalesOrder__r.OracleCustAcctSiteID__c, 
                           SalesOrder__r.OracleSiteUseID__c, 
                           SalesOrder__r.NotToBeShownOnRD__c 
                    FROM Receipt__c 
                    WHERE Oracle_Id_Temporary__c = null 
                    AND Account__r.OraclePartyId__c != null 
                    AND SalesOrder__r.OraclePartySiteID__c != null 
                    AND SalesOrder__r.NotToBeShownOnRD__c = false 
                    AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                    AND SalesOrder__r.ProjectName__c = :projectName 
                    AND Id IN :ReciptIds
                ]);
            } else if(projectName == null && phaseName != null){
                return Database.getQueryLocator([
                    SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, 
                           SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, 
                           SalesOrder__r.ProjectName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                           PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, 
                           TransactionDate__c, PaymentEscrowAccount__r.IBANNo__c, 
                           PaymentEscrowAccount__r.Name, TransactionNumber__c, 
                           ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, 
                           ChequeDate__c, TotalAmount__c, Bank__c, Status__c, 
                           SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                           SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c, 
                           SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, 
                           SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, 
                           SalesOrder__r.OracleCustAcctSiteID__c, 
                           SalesOrder__r.OracleSiteUseID__c, 
                           SalesOrder__r.NotToBeShownOnRD__c 
                    FROM Receipt__c 
                    WHERE Oracle_Id_Temporary__c = null 
                    AND Account__r.OraclePartyId__c != null 
                    AND SalesOrder__r.OraclePartySiteID__c != null 
                    AND SalesOrder__r.NotToBeShownOnRD__c = false 
                    AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                    AND SalesOrder__r.Unit__r.Phase__r.Name = :phaseName
                    AND Id IN :ReciptIds
                ]);
            } else {
                return Database.getQueryLocator([
                    SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, 
                           SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, 
                           SalesOrder__r.ProjectName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                           PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, 
                           TransactionDate__c, PaymentEscrowAccount__r.IBANNo__c, 
                           PaymentEscrowAccount__r.Name, TransactionNumber__c, 
                           ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, 
                           ChequeDate__c, TotalAmount__c, Bank__c, Status__c, 
                           SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                           SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c, 
                           SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, 
                           SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, 
                           SalesOrder__r.OracleCustAcctSiteID__c, 
                           SalesOrder__r.OracleSiteUseID__c, 
                           SalesOrder__r.NotToBeShownOnRD__c 
                    FROM Receipt__c 
                    WHERE Oracle_Id_Temporary__c = null 
                    AND Account__r.OraclePartyId__c != null 
                    AND SalesOrder__r.OraclePartySiteID__c != null 
                    AND SalesOrder__r.NotToBeShownOnRD__c = false 
                    AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                    AND Id IN :ReciptIds
                ]);
            }
        } else {
            if(projectName != null && phaseName != null){
                return Database.getQueryLocator([
                    SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, 
                           SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, 
                           SalesOrder__r.ProjectName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                           PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, 
                           TransactionDate__c, PaymentEscrowAccount__r.IBANNo__c, 
                           PaymentEscrowAccount__r.Name, TransactionNumber__c, 
                           ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, 
                           ChequeDate__c, TotalAmount__c, Bank__c, Status__c, 
                           SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                           SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c, 
                           SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, 
                           SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, 
                           SalesOrder__r.OracleCustAcctSiteID__c, 
                           SalesOrder__r.OracleSiteUseID__c, 
                           SalesOrder__r.NotToBeShownOnRD__c 
                    FROM Receipt__c 
                    WHERE Oracle_Id_Temporary__c = null 
                    AND Account__r.OraclePartyId__c != null 
                    AND SalesOrder__r.OraclePartySiteID__c != null 
                    AND SalesOrder__r.NotToBeShownOnRD__c = false 
                    AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                    AND SalesOrder__r.ProjectName__c = :projectName 
                    AND SalesOrder__r.Unit__r.Phase__r.Name = :phaseName
                ]);
            } else if(projectName != null && phaseName == null){
                return Database.getQueryLocator([
                    SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, 
                           SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, 
                           SalesOrder__r.ProjectName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                           PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, 
                           TransactionDate__c, PaymentEscrowAccount__r.IBANNo__c, 
                           PaymentEscrowAccount__r.Name, TransactionNumber__c, 
                           ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, 
                           ChequeDate__c, TotalAmount__c, Bank__c, Status__c, 
                           SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                           SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c, 
                           SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, 
                           SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, 
                           SalesOrder__r.OracleCustAcctSiteID__c, 
                           SalesOrder__r.OracleSiteUseID__c, 
                           SalesOrder__r.NotToBeShownOnRD__c 
                    FROM Receipt__c 
                    WHERE Oracle_Id_Temporary__c = null 
                    AND Account__r.OraclePartyId__c != null 
                    AND SalesOrder__r.OraclePartySiteID__c != null 
                    AND SalesOrder__r.NotToBeShownOnRD__c = false 
                    AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                    AND SalesOrder__r.ProjectName__c = :projectName
                ]);
            } else if(projectName == null && phaseName != null){
                return Database.getQueryLocator([
                    SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, 
                           SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, 
                           SalesOrder__r.ProjectName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                           PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, 
                           TransactionDate__c, PaymentEscrowAccount__r.IBANNo__c, 
                           PaymentEscrowAccount__r.Name, TransactionNumber__c, 
                           ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, 
                           ChequeDate__c, TotalAmount__c, Bank__c, Status__c, 
                           SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                           SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c, 
                           SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, 
                           SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, 
                           SalesOrder__r.OracleCustAcctSiteID__c, 
                           SalesOrder__r.OracleSiteUseID__c, 
                           SalesOrder__r.NotToBeShownOnRD__c 
                    FROM Receipt__c 
                    WHERE Oracle_Id_Temporary__c = null 
                    AND Account__r.OraclePartyId__c != null 
                    AND SalesOrder__r.OraclePartySiteID__c != null 
                    AND SalesOrder__r.NotToBeShownOnRD__c = false 
                    AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                    AND SalesOrder__r.Unit__r.Phase__r.Name = :phaseName
                ]);
            } else {
                return Database.getQueryLocator([
                    SELECT Id, Name, Receipt_Amount__c, Receipt_Approved_Date__c, Account__c, 
                           SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c, 
                           SalesOrder__r.ProjectName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.ProjectName__c, 
                           PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, 
                           TransactionDate__c, PaymentEscrowAccount__r.IBANNo__c, 
                           PaymentEscrowAccount__r.Name, TransactionNumber__c, 
                           ExpressionOfInterest__c, Modeofpayment__c, ReceiptDate__c, 
                           ChequeDate__c, TotalAmount__c, Bank__c, Status__c, 
                           SalesOrder__r.Unit__r.Name, Account__r.OraclePartyId__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, 
                           SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                           SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c, 
                           SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c, 
                           SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name, 
                           SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c, 
                           EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, 
                           SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c, 
                           SalesOrder__r.OracleCustAcctSiteID__c, 
                           SalesOrder__r.OracleSiteUseID__c, 
                           SalesOrder__r.NotToBeShownOnRD__c 
                    FROM Receipt__c 
                    WHERE Oracle_Id_Temporary__c = null 
                    AND Account__r.OraclePartyId__c != null 
                    AND SalesOrder__r.OraclePartySiteID__c != null 
                    AND SalesOrder__r.NotToBeShownOnRD__c = false 
                    AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                ]);
            }
        }
    }


    global void execute(Database.BatchableContext bc, List<Receipt__c> recLst) {
        for(Receipt__c rec : recLst){
            Set<String> receiptIdSet = new Set<String>();
            receiptIdSet.add(rec.id);
            OIC_ManageSalesforceDataController.createReceipt(receiptIdSet);
        }       

    }    
    

       

    global void finish(Database.BatchableContext bc) {
        System.debug('ReceiptEBSIntegrationBatch completed successfully.');
    }
    
    
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new ReceiptEBSIntegrationBatch(projectName, phaseName,ReciptIds));
    }    

}