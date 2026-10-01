/**********************************************************************************************************************
* Name               : salesorderQueuableService                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes.
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            29 Sep 2025     Initial Draft       
* 2.0			Manoj					20 May 2026		add logic bypass
***********************************************************************************************************************/
public class salesorderQueuableService implements Queueable, Database.AllowsCallouts {
    public Set<string> soIds;
    public salesorderQueuableService(Set<string> soRecIds) {
        this.soIds = soRecIds;
    }
    public void execute(QueueableContext context) {
        // Call sales order sync
       // First make account callout   
        string soResponce;  //2.0
        set<string> accIds = new set<string>();
        set<string> soRecsIds = new set<string>();
        // 2.0
        list<SalesOrder__c> soListCurrent = [Select Id, CustomerAccount__c,OracleCustAcctSiteID__c,CustomerAccount__r.OraclePartyId__c,CustomerAccount__r.OICIntegrationStatus__c from SalesOrder__c where Id in: soids];
        if(soListCurrent <> null && !soListCurrent.isEmpty()){
            for(SalesOrder__c so: soListCurrent){
                if(so.CustomerAccount__r.OICIntegrationStatus__c != 'S'){
                    accIds.add(so.CustomerAccount__c);
                }
                if(so.id != null && so.OracleCustAcctSiteID__c == null){ //start 2.0
                    soRecsIds.add(so.id);
                } else {
                    soResponce = 'S';
                }  // End 2.0              
            }
        }
		string accservicesResponce;
        if(!accIds.isEmpty()){
            accservicesResponce = OIC_ManageSalesforceDataControllerV1.createAccount(accIds);                     
        }
        
         if(soRecsIds.size() > 0 || accservicesResponce == 'S'){
               soResponce=  OIC_ManageSalesforceDataControllerV1.createSalesOrderAndSOInstallments(soRecsIds);
            } 
        // If success or required condition met, chain next
        if(soResponce == 'S') {
            //System.enqueueJob(new ReceiptQueueable(soIds)); // removed and aligned with Ibrahims and Ramya dessign flows.
            System.enqueueJob(new InvoiceQueueable(soIds));
        }
    }
}