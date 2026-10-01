/**********************************************************************************************************************
* Name               : DirectDebitTransactionTrigger                                                        
* Description        : Apextrigger to handle all the befor and after events for the Direct Debit Transaction record.
* Usage              : Called by system processes on DirectDebitTransaction record create, update, delete, undelete
* Created By         : Activeminds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh        				22 Mar2025      Initial Draft       
******************************************************************************************************************/
trigger DirectDebitTransactionTrigger on DirectDebit_Transactions__c (after insert, after update, before insert, before update) {
	new DirectDebitTransactionTriggerHandler().run('DirectDebitTransactions');
}