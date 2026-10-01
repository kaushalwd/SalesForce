/**********************************************************************************************************************
* Name               : Pr_InvoiceQueueable                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes.
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            20 FEB 2026     Initial Draft       

***********************************************************************************************************************/
public class Pr_InvoiceQueueable implements Queueable, Database.AllowsCallouts {
    public Set<string> soIds;   
    public String ProjectExcludeLst = System.Label.Project_Excluded;    
    public Pr_InvoiceQueueable(Set<String> soRecIds) {
        this.soIds = soRecIds;       
    }
    public void execute(QueueableContext context) {
        // Call invoice sync
          List<String> ProjList = new List<String>();
        for (String c : ProjectExcludeLst.split(',')) {
            ProjList.add(c.trim());
        }
       set<string> InvoiceIds =new set<string>();
        for(Invoice__c invRec : [select id,Is_ADM_Fees_and_Dari_charges__c,Charge__r.name,Charge__r.Type__c,Sales_Order__r.ProjectName__c from Invoice__c where Sales_Order__c =:soIds and Sales_Order__r.ProjectName__c NOT IN : ProjList]){
            if(invRec.Is_ADM_Fees_and_Dari_charges__c == true && invRec.Charge__r.Type__c == 'ADM & Dari Fee'){
                InvoiceIds.add(invRec.id);
                system.debug('InvoiceIds22---'+InvoiceIds);
            }
            if(invRec.Charge__r.Type__c == 'Modon Fee'){ 
                InvoiceIds.add(invRec.id);
            }
        }
        if(InvoiceIds.size()>0){
            system.debug('InvoiceIds---'+InvoiceIds);
            for(Id installId : InvoiceIds){
                system.debug('installId35---'+installId);
                Set<String> installmentIdsTemp = new Set<String>();
                installmentIdsTemp.add(installId);
                 InvoiceServiceHelper.sendInvoiceToOracle_Future(installmentIdsTemp); 
                
            }
            if (!Test.isRunningTest()) {
            System.enqueueJob(new ReceiptQueueable(soIds));
            }
        }
        // Last job in chain; end here
       
    }
}