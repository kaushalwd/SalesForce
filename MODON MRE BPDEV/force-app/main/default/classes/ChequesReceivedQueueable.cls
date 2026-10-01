/**********************************************************************************************************************
* Name               : ChequesReceivedQueueable                                                        
* Description        : This class is used to send cheque ack
* Usage              : Queueable class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    04 01 2026     Initial Draft
* 2.0           Suresh         			    24 04 2026     Added bounced notification
******************************************************************************************************************/
public class ChequesReceivedQueueable implements Queueable, Database.AllowsCallouts {
	
    private List<Receipt__c> lst_Receipts;
	private Map<Id, SObject> oldMap;
    public ChequesReceivedQueueable(List<Receipt__c> lst_Receipts, Map<Id, SObject> oldMap) {
        this.lst_Receipts = lst_Receipts;
        this.oldMap = oldMap;
    }

    public void execute(QueueableContext qc) {
        String ReceiptNotificationEnable = System.Label.ReceiptNotificationEnable;
        if((lst_Receipts.size() > 0 && ReceiptNotificationEnable == 'Yes') || Test.isRunningTest()){
            Set<Id> set_ReceiptId = new Set<Id>();
            Set<Id> set_SOId = new Set<Id>();
            List<Receipt__c> lst_EmailReceipt = new List<Receipt__c>();
            for(Receipt__c obj_Receipt : lst_Receipts){
                set_ReceiptId.add(obj_Receipt.Id);
            }
            if(lst_Receipts.size() > 0 && oldMap != null){
                 for(Receipt__c obj_Rec : lst_Receipts){
                    Receipt__c oldRec = oldMap!= null?(Receipt__c) oldMap.get(obj_Rec.Id):null;
                    //2.0 - Added bounced notification 
                    if(oldRec!= null && oldRec.Status__c != obj_Rec.Status__c 
                       && (obj_Rec.Status__c == 'Cleared' || obj_Rec.Status__c == 'Bounced')){
                       lst_EmailReceipt.add(obj_Rec);
                    } else {}
                 }
                if(lst_EmailReceipt.size() > 0){
                    Database.executeBatch(new ChequesClearedBatch(lst_EmailReceipt), 1);
                }
            }           
        }
    }
}