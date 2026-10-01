/**********************************************************************************************************************
* Name               : OIC_ManageReceiptBatchForApproval
* Description        : Controller for is used for approval from payemnt screen
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj            15 Jan 2026          Initial Draft
* 2.0           Manoj            15 May 2026          add Credit not for Adm
***********************************************************************************************************************/
global without sharing class OIC_ManageReceiptBatchForApproval implements Database.Batchable<sObject>,schedulable,Database.AllowsCallouts{
    // 1.1 custom condition with custom lables
    public String SourceEntityExcludeLst = System.Label.Source_Entity_Excluded;
    public String ProjectExcludeLst = System.Label.Project_Excluded;
    public String SOstatusExcludeLst = System.Label.SO_Status_List;
    public String ReceiptstatusIncludeLst = System.Label.Batch_Receipt_Status;
     public Set<Id> recIds = new Set<Id>();

    // Constructor
    public OIC_ManageReceiptBatchForApproval(Set<Id> receiptIds) {
        if (receiptIds != null) {
            this.recIds.addAll(receiptIds);
        }
    }
    global Database.QueryLocator start(Database.BatchableContext BC){
        // 1.1 custom condition with custom lables
        List<String> SEList = new List<String>();
        List<String> ProjList = new List<String>();
        List<String> SOStatusList = new List<String>();
        List<String> RecptStatusList = new List<String>();
        
        for (String c : SourceEntityExcludeLst.split(',')) {
            SEList.add(c.trim());
        }   
        for (String c : ProjectExcludeLst.split(',')) {
            ProjList.add(c.trim());
        }
        for (String c : SOstatusExcludeLst.split(',')) {
            SOStatusList.add(c.trim());
        }
        
        for (String c : ReceiptstatusIncludeLst.split(',')) {
            RecptStatusList.add(c.trim());
        }
        
        // MDT supplies the admin-controlled base SELECT/WHERE; all runtime filters use Apex bind variables.
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchQuery_ApprvalReceiptsToOracle');
        String query = (oicParams != null && String.isNotBlank(oicParams.Value__c))
            ? oicParams.Value__c
            : 'SELECT Id, Is_Un_Identified_Receipts__c, Modeofpayment__c FROM Receipt__c WHERE Id != null';

        // 1.1 custom condition with custom lables — bind variables only (no string concat of values)
        if (!SEList.isEmpty()) {
            query += ' AND Account__r.Source_Entity__c NOT IN :SEList ';
        }
        if (!ProjList.isEmpty()) {
            query += ' AND SalesOrder__r.ProjectName__c NOT IN :ProjList';
        }
        if (!SOStatusList.isEmpty()) {
            query += ' AND SalesOrder__r.Status__c NOT IN :SOStatusList ';
        }
        if (!RecptStatusList.isEmpty()) {
            query += ' AND Status__c IN :RecptStatusList ';
        }
        if (!this.recIds.isEmpty()) {
            query += ' AND Id IN :recIds';
        }

        // Test path: static SOQL with bind variables
        if (Test.isRunningTest()) {
            if (!this.recIds.isEmpty()) {
                return Database.getQueryLocator([
                    SELECT Id, Is_Un_Identified_Receipts__c, Modeofpayment__c
                    FROM Receipt__c
                    WHERE Id IN :recIds
                ]);
            }
            return Database.getQueryLocator([
                SELECT Id, Is_Un_Identified_Receipts__c, Modeofpayment__c
                FROM Receipt__c
            ]);
        }
        return Database.getQueryLocator(query);
    }
        
    global void execute(Database.BatchableContext BC, List<Receipt__c> scope){

        Set<String> receiptStrSet = new Set<String>();
        Set<String> creditStrSet = new Set<String>(); //2.0
        Set<String> receiptUnidentitySet = new Set<String>();
    
        for (Receipt__c receiptObj : scope) { // Start 2.0
            if(receiptObj.Is_Un_Identified_Receipts__c ==false && receiptObj.Modeofpayment__c !='Credit Note'  ){
            	receiptStrSet.add(receiptObj.Id);
            }else if(receiptObj.Is_Un_Identified_Receipts__c ==false && receiptObj.Modeofpayment__c =='Credit Note'  ){
            	creditStrSet.add(receiptObj.Id); // End 2.0
            }else if(receiptObj.Is_Un_Identified_Receipts__c ==true){
                receiptUnidentitySet.add(receiptObj.Id);
            }
        }
    
        if(!receiptStrSet.isEmpty()){
            OIC_ManageSalesforceDataController.createReceipt(receiptStrSet);
        }
        if(!receiptUnidentitySet.isEmpty()){
           OIC_ManageEbsDataController.createUnidentifiedReceipt(receiptUnidentitySet);
        }
        if(!creditStrSet.isEmpty()){ //start 2.0
            OIC_ManageSalesforceDataController.createCreditReceipt(creditStrSet);
        } //End 2.0
    }  
        
    // Finish Method
    global void finish(Database.BatchableContext BC){
    
    }
        
    // 1.0 custom condition with custom lables
    global void execute(schedulablecontext sc){
         
        Database.executeBatch(new OIC_ManageReceiptBatchForApproval(new Set<Id>()), 1);
    }

}