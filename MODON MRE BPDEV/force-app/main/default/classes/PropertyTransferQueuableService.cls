/**********************************************************************************************************************
* Name               : PropertyTransferQueuableService                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across After complete Property Transfer, Triggers and Batch classes sync to Ebs.
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            19 Feb 2026     Initial Draft       

***********************************************************************************************************************/
public class PropertyTransferQueuableService implements Queueable, Database.AllowsCallouts {
	public Set<string> soIds;
    public String ProjectExcludeLst = System.Label.Project_Excluded;
    
    public PropertyTransferQueuableService(Set<string> soRecIds) {
        this.soIds = soRecIds;
    }
    public void execute(QueueableContext context) {
        // First make PDC is Cancelled and account,Sales Order and Invoice callout 
        set<string> accIds = new set<string>();
        set<string> soRecsIds = new set<string>();
        List<String> ProjList = new List<String>();
        for (String c : ProjectExcludeLst.split(',')) {
            ProjList.add(c.trim());
        }
        list<SalesOrder__c> soListCurrent = [Select Id, Old_Account__c,Resale_Transfer_Date__c,CustomerAccount__c,CustomerAccount__r.OraclePartyId__c,CustomerAccount__r.OICIntegrationStatus__c from SalesOrder__c where Id in: soids and ProjectName__c NOT IN : ProjList];
        if(soListCurrent <> null && !soListCurrent.isEmpty()){
            for(SalesOrder__c so: soListCurrent){
                if(so.CustomerAccount__r.OICIntegrationStatus__c != 'S'){
                    accIds.add(so.CustomerAccount__c);
                }
                if(so.id != null && so.Old_Account__c != null && so.Resale_Transfer_Date__c == system.Today() ){
                    soRecsIds.add(so.id);
                }                
            }
        }
		string accservicesResponce;
        if(!accIds.isEmpty() ){
            accservicesResponce = OIC_ManageSalesforceDataControllerV1.createAccount(accIds);                     
        }
       // string soResponce;
         if((soRecsIds.size() > 0 || accservicesResponce == 'S')&& !Test.isRunningTest()){               
             System.enqueueJob(new TransferQueueableSO(soIds));
         } 
       /* // If success or required condition met, chain next
        if(soResponce == 'S') {
           // System.enqueueJob(new InvoiceQueueable(soRecsIds,true));
            Id invoiceJobId = System.enqueueJob(new InvoiceQueueable(soIds, true));
            AsyncApexJob job = [ SELECT Id, Status FROM AsyncApexJob WHERE Id = :invoiceJobId];

            if(job.Status == 'Completed'){
                System.enqueueJob(new ReceiptQueueable(soIds, true));
            }
        }*/
        
    }
}