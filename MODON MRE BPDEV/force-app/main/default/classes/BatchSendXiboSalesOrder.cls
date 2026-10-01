/**********************************************************************************************************************
* Name               : BatchSendXiboSalesOrder                                                        
* Description        : This class is used to send email for customer when salesorder 
* Usage              : BatchSendXiboSalesOrder
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           raghu.gajjela@amgs        		22 DEC 2025    	 Initial Draft      

******************************************************************************************************************/

public class BatchSendXiboSalesOrder implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {
 
    private Set<Id> salesOrderIds;
 
    public BatchSendXiboSalesOrder(Set<Id> soIds) {

        this.salesOrderIds = soIds;

    }
 
    public Database.QueryLocator start(Database.BatchableContext bc) {

        return Database.getQueryLocator([SELECT Id FROM SalesOrder__c WHERE Id IN :salesOrderIds ]);

    }
 
    public void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
 
        Set<String> stringIds = new Set<String>();
 
        for (SalesOrder__c so : scope) {

            stringIds.add(String.valueOf(so.Id));

        }
 
        // Calling Xibo

        if (!stringIds.isEmpty()) {

            SendRequestToXiboSalesOrder.callSalesOrderXiboService(stringIds);

        }

    }
 
    public void finish(Database.BatchableContext bc) {

        System.debug('BatchSendXiboSalesOrder has completed.');

    }

}