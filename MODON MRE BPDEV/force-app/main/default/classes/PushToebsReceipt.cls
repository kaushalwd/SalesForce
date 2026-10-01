/**********************************************************************************************************************
 * Name               : PushToebsReceipt
 * Description        : This class is helper for Repush all the receipt api to EBS
 * Usage              : Called from screen flows from Quick Action buttons
 * Created By         : Kumaravel 
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Kumaravel                         12 Jan 2025       Initial Draft
 * 2.0           Manoj							   20 May 2026		 Add All callouts
******************************************************************************************************************/

public class PushToebsReceipt {
    public PushToebsReceipt() {

    }

    @InvocableMethod(label='Receipt OIC Callout' description='details page callout')
    public static void receiptCalloutInvokeFromFlowDetailsPageAction(list<string> recordId) {
        set<string> recIds = new set<string>(recordId);
        sendReceiptsToOracle_Future(recIds);
    }
    
    @future(callout = true)
    public static void sendReceiptsToOracle_Future(set<string> recIds){
        // Start 2.0
        Set<String> receiptStrSet = new Set<String>();
        Set<String> creditStrSet = new Set<String>(); //2.0
        Set<String> receiptUnidentitySet = new Set<String>();
    
        for(Receipt__c recRec : [SELECT Id, Is_Un_Identified_Receipts__c,Modeofpayment__c FROM Receipt__c where id IN: recIds]){ 
            if(recRec.Is_Un_Identified_Receipts__c ==false && recRec.Modeofpayment__c !='Credit Note'  ){
            	receiptStrSet.add(recRec.Id);
            }else if(recRec.Is_Un_Identified_Receipts__c ==false && recRec.Modeofpayment__c =='Credit Note'  ){
            	creditStrSet.add(recRec.Id);
            }else if(recRec.Is_Un_Identified_Receipts__c ==true){
                receiptUnidentitySet.add(recRec.Id);
            }
        }
    
        if(!receiptStrSet.isEmpty()){
            OIC_ManageSalesforceDataController.createReceipt(receiptStrSet);
        }
        if(!receiptUnidentitySet.isEmpty()){
           OIC_ManageEbsDataController.createUnidentifiedReceipt(receiptUnidentitySet);
        }
        if(!creditStrSet.isEmpty()){ 
            OIC_ManageSalesforceDataController.createCreditReceipt(creditStrSet);
        } //End 2.0
        
    }
    
}