/**********************************************************************************************************************
* Name               : ReceiptTriggerService                                                      
* Description        : This class is used for ReceiptTriggerHandler
* Usage              : 
* Created By         : Karunakar                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Karunakar         			22 Aug 2026     Initial Draft 
******************************************************************************************************************/
public without sharing class ReceiptTriggerService {
    public static void systemSyncReceipt(List<Receipt__c> newList) {
        Set<String> receiptsToSync = new Set<String>();
        for(Receipt__c newReceipt : newList) {
            if(newReceipt.System_Sync__c && newReceipt.Business_Process__c != null) {
                receiptsToSync.add(newReceipt.Id);
            }
        }

        if(!receiptsToSync.isEmpty() && receiptsToSync != null) {
            ReceiptTriggerHelper.sendReceiptsToOracle_Future(receiptsToSync);
        }
    }
}