/**********************************************************************************************************************
* Name               : SPAFinalCustomerCopyBatch                                                        
* Description        : This class is used to send the final copy to customer
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    05 10 2025     Initial Draft       
******************************************************************************************************************/
global without sharing class SPAFinalCustomerCopyBatch implements Database.Batchable<sObject>,Database.AllowsCallouts {
	global List<SalesOrder__c> records;
    
    global SPAFinalCustomerCopyBatch(List<SalesOrder__c> listSO) {
        this.records = listSO;
    }
    
    global Iterable<SObject> start(Database.BatchableContext BC) {
 		return records;
    }    
    
    global void execute(Database.BatchableContext BC, List<SalesOrder__c> scope) {
        List<SalesOrder__c> listSO = (List<SalesOrder__c>)scope;
       	for(SalesOrder__c obj_SO : listSO){
            SPAFinalCustomerCopy.sendFinalCopySPAToCustomer(obj_SO.Id);               	 
        }
    }
    global void finish(Database.BatchableContext BC) {}
}