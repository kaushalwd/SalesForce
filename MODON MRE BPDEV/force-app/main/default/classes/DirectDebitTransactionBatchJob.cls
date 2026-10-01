/**********************************************************************************************************************
* Name               : DirectDebitTransactionBatchJob                                                        
* Description        : This class is used to send the payments to FAB bank
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    18 May 2025     Initial Draft       
******************************************************************************************************************/
global without sharing class DirectDebitTransactionBatchJob implements Database.Batchable<sObject>,Database.AllowsCallouts {
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        Date twoDaysLater = Date.today().addDays(3);
        return Database.getQueryLocator([select Id, Name, InstallmentAmount__c, Instalment_Number__c, InstalmentPaymentDueDate__c, 
                                         IsHandoverPayment__c, Milestone__c, MilestoneDate__c, MilestoneDescription__c, 
                                         MilestoneNumber__c, PaymentStatus__c, SalesOrder__c, SalesOrder__r.Direct_Debit_Request__c,
                                         SalesOrder__r.Direct_Debit_Request__r.Approve__c 
                                         from SalesOrderInstallments__c where MilestoneDate__c > TODAY and MilestoneDate__c < :twoDaysLater
                                         and SalesOrder__r.Direct_Debit_Request__r.Approve__c = true
                                         and PaymentStatus__c != 'Paid']);
    }

    global void execute(Database.BatchableContext BC, List<SalesOrderInstallments__c> scope) {
       List<DirectDebit_Transactions__c> lst_DDTransaction = new List<DirectDebit_Transactions__c>();
        for(SalesOrderInstallments__c obj_Installment : scope){
            if(obj_Installment.PaymentStatus__c != 'Paid' 
               && obj_Installment.SalesOrder__r.Direct_Debit_Request__r.Approve__c){
                	DirectDebit_Transactions__c obj_DDTransaction = new DirectDebit_Transactions__c();
                    obj_DDTransaction.Direct_Debit_Request__c =  obj_Installment.SalesOrder__r.Direct_Debit_Request__c;
                    obj_DDTransaction.Collection_Amount__c = obj_Installment.InstallmentAmount__c;
                    obj_DDTransaction.Currency__c = 'AED';
                    obj_DDTransaction.Request_Type__c = 'Collection';
                    obj_DDTransaction.SOInstallment__c = obj_Installment.Id;
                    lst_DDTransaction.add(obj_DDTransaction);
            }
        }
        if(lst_DDTransaction.size() > 0){
            insert lst_DDTransaction;
        }
    }

    global void finish(Database.BatchableContext BC) {}
}