/**********************************************************************************************************************
* Name               : OIC_ManageReceiptRevDataBatch
* Description        : Controller for is used for  Receipt Reversal from payemnt record
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj            16 Mar 2026          Initial Draft

***********************************************************************************************************************/
global without sharing class OIC_ManageReceiptRevDataBatch implements Database.Batchable<sObject>,Database.AllowsCallouts{
    
	 private final Map<Id, String> receiptReversalMap;
 
    public OIC_ManageReceiptRevDataBatch(Map<Id, String> receiptReversalMap) {
        this.receiptReversalMap = receiptReversalMap;
    }
     global Database.QueryLocator start(Database.BatchableContext BC){
        Set<Id> ids = (receiptReversalMap != null) ? receiptReversalMap.keySet() : new Set<Id>();
        if(Test.isRunningTest()){
            return Database.getQueryLocator([
                SELECT Id, OraclePartyId__c FROM Receipt__c LIMIT 1
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, OraclePartyId__c FROM Receipt__c WHERE Id IN :ids
            ]);
        }
     }
     global void execute(Database.BatchableContext BC, List<Receipt__c> scope){
         if (scope.isEmpty()) return;
         Map<Id, OIC_ManageReceiptReversal.ReceiptData> receiptMap = new Map<Id, OIC_ManageReceiptReversal.ReceiptData>();
         for(Receipt__c rec: scope){             
             String reason = receiptReversalMap != null ? receiptReversalMap.get(rec.Id) : null;
             receiptMap.put(rec.Id, new OIC_ManageReceiptReversal.ReceiptData(reason, null));
         }        
         if (!receiptMap.isEmpty()) {
             OIC_ManageReceiptReversal.receiptReversalEbsService(receiptMap);
         }
     }
    
     global void finish(Database.BatchableContext BC){
    
    }
        
    // 1.1 custom condition with custom lables
    global void execute(schedulablecontext sc){
        Database.executeBatch(new OIC_ManageSalesforceSalesOrderDataBatch());
    }
    
}