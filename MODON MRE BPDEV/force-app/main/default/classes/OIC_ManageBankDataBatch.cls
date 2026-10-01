/**********************************************************************************************************************
* Name               : OIC_ManageBankDataBatch                                                        
* Description        : This class is used to create a debit fund in EBS
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    23 04 2026     Initial Draft       
******************************************************************************************************************/
global without sharing class OIC_ManageBankDataBatch implements Database.Batchable<sObject>,Database.AllowsCallouts {
	private final List<String>  invoiceIds;
    public OIC_ManageBankDataBatch(List<String> invoiceIds){
        this.invoiceIds = invoiceIds    != null ? invoiceIds    : new List<String>();
    }
    global Database.QueryLocator start(Database.BatchableContext BC) {
        List<String> excludeStatuses = new List<String>{'Modon - Egypt'};
        return Database.getQueryLocator([SELECT Id, Name, OraclePartyId__c, Transaction_Type__c,Service_Request__r.UnitId__r.Name, Service_Request__r.UnitId__c,Account__c, Account__r.Bank_Account_Number__c, Account__r.Bank_Branch_Name__c, 
                                                Account__r.Bank_Country__c, Account__r.Bank_Name__c,Account__r.Swift_Code__c, Service_Request__r.SalesOrder__r.VirtualAccount__r.Escrow_Bank_Name__c,                                  
                                                Account__r.IBAN_Number__c, Service_Request__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c,Service_Request__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c, 
                                                Service_Request__r.SalesOrder__r.VirtualAccount__r.Name,Service_Request__r.SalesOrder__r.VirtualAccount__r.Swift_Code__c, 
                                                Transfer_Sales_Order__c,Transfer_Sales_Order__r.VirtualAccount__r.Name,Transfer_Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c,Transfer_Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c,
                                                Transfer_Sales_Order__r.VirtualAccount__r.Swift_Code__c,Transfer_Sales_Order__r.VirtualAccount__r.Escrow_Bank_Name__c,
                                                Transfer_Sales_Order__r.CustAcctId__c,Transfer_Sales_Order__r.OracleCustAcctSiteID__c,Transfer_Sales_Order__r.OraclePartySiteID__c,Transfer_Sales_Order__r.OracleSiteUseID__c,Transfer_Sales_Order__r.Name,
                                                Service_Request__r.SalesOrder__r.CustAcctId__c,Service_Request__r.SalesOrder__r.OracleCustAcctSiteID__c,
                                                Service_Request__r.SalesOrder__r.OraclePartySiteID__c,Service_Request__r.SalesOrder__r.OracleSiteUseID__c,
                                                Service_Request__r.SalesOrder__r.Name from Invoice__c  where id IN : invoiceIds and Service_Request__c != null and Transaction_Type__c != null
                                                and Account__c != null and Transaction_Type__c IN ('Refund','Customer Refund') 
                                                and Status__c = 'In Progress' and Service_Request__r.SalesOrder__r.Source_Entity__c NOT IN :excludeStatuses]);
    }    
   		
    global void execute(Database.BatchableContext BC, List<Invoice__c> scope) {
       	set<String> invoiceIds = new set<String>();
        for(Invoice__c obj_Inv : (List<Invoice__c>)scope){
            invoiceIds.add(obj_Inv.Id);
        }
        OIC_ManageBankData.createRefundMemo(invoiceIds);
    }
    global void finish(Database.BatchableContext BC) {}
}