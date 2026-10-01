/*************************************************************************************
* Name        : OIC_ManageRevenueRecognitionBatch
* Description : Batch class to process Invoice__c records and send revenue recognition
*               data to Oracle via OIC callout.
* Created By  : Active Minds
* ---------------------------------------------------------------------------------
* Version   Author   Date         Comment
* 1.0       Manoj    26-04-2026   Initial Draft
*************************************************************************************/
public class OIC_ManageRevenueRecognitionBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts {

    // Optional: filter by specific invoice IDs (e.g. triggered from a scheduler)
    private Set<String> soIds;
    private string ProjectName = null;
    private Date startDate = null;
    public static Date targetDate = null;
    
    // Constructor — no filter, processes all eligible invoices
    /**
     * Description : Initializes batch with no filters,         
     *               processes all eligible SalesOrders.        
     */
    public OIC_ManageRevenueRecognitionBatch() {}

    // Constructor — optional filter by invoice IDs
    /**
     * Description : Initializes batch with SO IDs, project     
     *               name, and start date as filters.           
     */
    public OIC_ManageRevenueRecognitionBatch(Set<String> soIds,string ProjectName, Date startDate) {
        this.soIds = soIds;
        this.ProjectName =ProjectName;
        this.startDate =startDate;
    }
	/**
     * Description : Builds dynamic SOQL query to fetch         
     *               eligible SalesOrder__c records.            
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> excludeStatuses  = new List<String>{ 'Modon - Egypt' };
        String SOstatusExcludeLst = System.Label.SO_Status_List;
        String MIREExcludelst = System.Label.MIRE_Exclude_List;
        String ModeofpaymentValues = System.Label.ModeofpaymentValues;
		list<String> SOList = new List<String>();
        for (String c : SOstatusExcludeLst.split(',')) SOList.add(c.trim());

        
        List<String> MIREList = new List<String>();
        for (String c2 : MIREExcludelst.split(',')) {
            if (c2 != null && c2.contains('^')) {
                MIREList.add(c2.replace('^', ',').trim());
            } else {
                MIREList.add(c2.trim());
            }
        }
        
        // Fix: SOQL Injection
        Date syncDate = Date.today();

        String query =
            'SELECT Id, Name, ProjectName__c, Unit__c, ' +
            'Unit__r.Pass_id__c, ' +
            'Unit__r.Phase__r.Project__r.ProjectNumber__c, ' +
            'Unit__r.Phase__r.EntityName__c, ' +
            'Unit__r.Building_No__c, ' +
            'TotalAmount__c, Status__c ' +
            'FROM SalesOrder__c ' +
            'WHERE Status__c NOT IN :SOList ' +
            'AND ProjectName__c NOT IN :MIREList ' +
            'AND Source_Entity__c NOT IN :excludeStatuses ' +
            'AND Unit__r.Pass_id__c != NULL';

        if (soIds != null && !soIds.isEmpty()) {
            query += ' AND Id IN :soIds';
        }

        if (ProjectName != null) {
            query += ' AND ProjectName__c = :ProjectName';
        }

        System.debug('query---- ' + query);

        return Database.getQueryLocator(query);
    }
	/**
     * Description : Aggregates invoice totals per SO and       
     *               triggers the OIC revenue recognition call. 
     */
    public void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
        Set<Id> soIds      = new Map<Id, SalesOrder__c>(scope).keySet();
    // ── Single aggregate — wrapper keyed by soId prevents duplicates ─────────
    Map<Id, OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary> invoiceSummaryBySO = new Map<Id, OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary>();
	targetDate = this.startDate != null ? startDate : Date.today();
        system.debug('InvoiceRunDate---'+ targetDate);
        system.debug('startDate---'+ startDate);
      for (AggregateResult ar : [
        SELECT SalesOrderInstallment__r.SalesOrder__c soId,
               SUM(InvoiceAmount__c)                  totalInvoice,
               SUM(TotalPaidAmount__c)                totalPaid
        FROM Invoice__c
        WHERE InvoiceStatus__c != 'Cancelled'
          AND SalesOrderInstallment__r.SalesOrder__c IN :soIds
          AND InvoiceDate__c < : targetDate
        GROUP BY SalesOrderInstallment__r.SalesOrder__c
    ]) {
        Id soId = (Id) ar.get('soId');

        // Map key = soId — duplicate soId from aggregate is impossible
        // but guard anyway with containsKey check
        if (!invoiceSummaryBySO.containsKey(soId)) {
            invoiceSummaryBySO.put(
                soId,
                new OIC_ManageRevenueRecognition.SalesOrderInvoiceSummary(
                    soId,
                    (Decimal) ar.get('totalInvoice'),
                    (Decimal) ar.get('totalPaid')
                )
            );
        }
    }

    if (invoiceSummaryBySO.isEmpty()) return;

    OIC_ManageRevenueRecognition.getRevenueRecognition(scope, invoiceSummaryBySO,targetDate);
    }
	/**
     * Description : Logs batch job completion and performs     
     *               any required post-processing steps.        
     */
    public void finish(Database.BatchableContext bc) {
        System.debug('OIC_ManageRevenueRecognitionBatch completed. Job ID: ' + bc.getJobId());
        // Optional: send email notification or log completion
    }
}