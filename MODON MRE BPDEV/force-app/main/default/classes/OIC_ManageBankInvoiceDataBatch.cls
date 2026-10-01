/**********************************************************************************************************************
* Name               : OIC_ManageBankInvoiceDataBatch                                                        
* Description        : This class is used to create a debit fund in EBS
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    23 04 2026     Initial Draft       
******************************************************************************************************************/
global without sharing class OIC_ManageBankInvoiceDataBatch implements Database.Batchable<sObject>,Database.AllowsCallouts {
	private final List<String>  invoiceIds;
    public OIC_ManageBankInvoiceDataBatch(List<String> invoiceIds){
        this.invoiceIds = invoiceIds    != null ? invoiceIds    : new List<String>();
    }
    global Database.QueryLocator start(Database.BatchableContext BC) {
        List<String> excludeStatuses = new List<String>{'Modon - Egypt'};
        return Database.getQueryLocator([SELECT Id, Name, OraclePartyId__c, Transaction_Type__c,Sales_Order__r.Unit__r.Name, 
                                         Sales_Order__r.Unit__c,Account__c, Account__r.Bank_Account_Number__c, 
                                         Account__r.Bank_Branch_Name__c, Account__r.Bank_Country__c, Account__r.Bank_Name__c,Account__r.Swift_Code__c, 
                                         Sales_Order__r.VirtualAccount__r.Escrow_Bank_Name__c, Account__r.IBAN_Number__c, 
                                         Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c, 
                                         Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c, Sales_Order__r.VirtualAccount__r.Name, 
                                         Sales_Order__r.VirtualAccount__r.Swift_Code__c, Sales_Order__r.CustAcctId__c, 
                                         Sales_Order__r.OracleCustAcctSiteID__c, Sales_Order__r.OraclePartySiteID__c, 
                                         Sales_Order__r.OracleSiteUseID__c, Sales_Order__r.Name from Invoice__c  where id IN : invoiceIds 
                                         and Transaction_Type__c != null and Account__c != null 
                                         and Transaction_Type__c IN ('Refund','Customer Refund') and InvoiceStatus__c = 'Paid' 
                                         and Sales_Order__r.Source_Entity__c NOT IN :excludeStatuses]);
    }    
   		
    global void execute(Database.BatchableContext BC, List<Invoice__c> scope) {
       	set<String> invoiceIds = new set<String>();
        for(Invoice__c obj_Inv : (List<Invoice__c>)scope){
            invoiceIds.add(obj_Inv.Id);
        }
        OIC_ManageBankInvoiceData.createRefundMemo(invoiceIds);
    }
    global void finish(Database.BatchableContext BC) {}
}