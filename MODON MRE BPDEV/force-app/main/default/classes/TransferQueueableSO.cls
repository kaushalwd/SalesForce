/**********************************************************************************************************************
* Name               : TransferQueueableSO                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across After complete Property Transfer, Triggers and Batch classes sync to Ebs for Salesorder .
* Created By         : Active minds Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj   	            19 Feb 2026     Initial Draft       

***********************************************************************************************************************/
public class TransferQueueableSO implements Queueable, Database.AllowsCallouts {

    public Set<string> soIds;

    public TransferQueueableSO(Set<string> soIds){
        this.soIds = soIds;
    }

    public void execute(QueueableContext context){

        // CALL ACCOUNT + SO CALLOUTS ONLY
        String soResponse = OIC_ManageSalesforceDataControllerV1.createSalesOrderAndSOInstallments(soIds);

        if(soResponse == 'S'){
            System.enqueueJob(new Pr_InvoiceQueueable(soIds));
        }
    }
}