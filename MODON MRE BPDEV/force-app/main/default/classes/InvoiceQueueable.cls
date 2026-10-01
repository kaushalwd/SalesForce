/**********************************************************************************************************************
* Name               : InvoiceQueueable                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes.
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            29 Sep 2025     Initial Draft       
* 2.0			Manoj					17 May 2026		Add check
***********************************************************************************************************************/
public class InvoiceQueueable implements Queueable, Database.AllowsCallouts {
    public Set<string> soIds;
    public InvoiceQueueable(Set<String> soRecIds) {
        this.soIds = soRecIds;
    }
    public void execute(QueueableContext context) {
        // Call invoice sync
          
       set<string> InvoiceIds =new set<string>();
        //2.0
        for(Invoice__c invRec : [select id,OraclePartyId__c,Is_ADM_Fees_and_Dari_charges__c,SalesOrderInstallment__c,SalesOrderInstallment__r.MilestoneNumber__c,Charge__r.name,Charge__r.Type__c from Invoice__c where Sales_Order__c =:soIds OR SalesOrderInstallment__r.SalesOrder__c =:soIds]){
            if(invRec.Is_ADM_Fees_and_Dari_charges__c == true || invRec.Charge__r.name == 'ADM & Dari Fee' && invRec.OraclePartyId__c == null){ // 2.0
                InvoiceIds.add(invRec.id);
                system.debug('InvoiceIds22---'+InvoiceIds);
            }
            if(invRec.SalesOrderInstallment__r.MilestoneNumber__c == 1 && invRec.OraclePartyId__c == null){ //2.0                
                InvoiceIds.add(invRec.id);
                system.debug('InvoiceIds26---'+InvoiceIds);
            }
            
        }
        string invRestrn;
        if(InvoiceIds.size()>0){
            system.debug('InvoiceIds---'+InvoiceIds);
            for(Id installId : InvoiceIds){
                system.debug('installId35---'+installId);
                Set<String> installmentIdsTemp = new Set<String>();
                installmentIdsTemp.add(installId);
                //invRestrn =OIC_ManageSalesforceDataControllerV1.createInstallment(installmentIdsTemp);
                    InvoiceServiceHelper.sendInvoiceToOracle_Future(installmentIdsTemp);

            }
        }
        // Last job in chain; end here
       
    }
}