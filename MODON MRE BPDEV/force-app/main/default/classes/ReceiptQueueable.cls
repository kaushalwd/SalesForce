/**********************************************************************************************************************
* Name               : ReceiptQueueable                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes for the Property Transfer PDC
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            20 Feb 2026     Initial Draft       

***********************************************************************************************************************/
public class ReceiptQueueable implements Queueable, Database.AllowsCallouts {
    public Set<string> soIds;
    public String ProjectExcludeLst = System.Label.Project_Excluded;
    public ReceiptQueueable(Set<String> soRecIds) {
        this.soIds = soRecIds;
         
    }
    public void execute(QueueableContext context) {
        if(this.soIds == null || this.soIds.isEmpty()){
            return;
        }
        List<String> ProjList = new List<String>();
        for (String c : ProjectExcludeLst.split(',')) {
            ProjList.add(c.trim());
        }
        map<id,Receipt__c> updateReceiptMap =new map<id,Receipt__c>();
         Set<String> receiptIdsForCallout = new Set<String>();
        for(Receipt__c recRec : [select id,Name,SalesOrder__c,Cheque_Bounce_Reason__c,SalesOrder__r.Old_Account__c,SalesOrder__r.CustomerAccount__c,SalesOrder__r.Resale_Transfer_Date__c,SalesOrder__r.Resale__c,OraclePartyId__c,Status__c from Receipt__c where SalesOrder__c =:soIds and Status__c IN ('Cancelled') and OraclePartyId__c != null AND Cancelled_Transfer_Date__c =: System.Today() AND  SalesOrder__r.ProjectName__c NOT IN : ProjList ]){
       		   Map<id,string> ReceiptMap =new map<id,string>();
            	ReceiptMap.put(recRec.id,recRec.Cheque_Bounce_Reason__c);
                // Single bulk callout
                if (!Test.isRunningTest()) {
                	OIC_ManageReceiptReversal.sendReceiptToOracle_Future(ReceiptMap);
                }
            }        
    }
}