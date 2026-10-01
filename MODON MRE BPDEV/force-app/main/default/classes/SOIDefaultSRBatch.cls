/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
* 2.0           sivannaryana.p@modon.com     20-07-2026      Default Process Changes 
* 3.0           sivannaryana.p@modon.com     31-07-2026      Adding Custom Label to make it dynamic
**********************************************************************************************************************/
public class SOIDefaultSRBatch implements Database.Batchable<SObject>, Schedulable {

    private Set<Id> soinstallIds;

 
    public SOIDefaultSRBatch(Set<Id> soiIds) {
        this.soinstallIds = soiIds;
    }

  
    public SOIDefaultSRBatch() {
        this.soinstallIds = null;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
       // 3.0 Starts
        Integer defaultDays = 10; // Default value
        if (!String.isBlank(System.Label.Default_Days)) {
            defaultDays = Integer.valueOf(System.Label.Default_Days);
        }
       Date cutoffDate = Date.today().addDays(-defaultDays);
       //Date cutoffDate = Date.today().addDays(-10);
       
        List<String> statusList = new List<String>();
        if (!String.isBlank(System.Label.Default_Exclude_Status)) {
            statusList = System.Label.Default_Exclude_Status.split(',');
            for (Integer i = 0; i < statusList.size(); i++) {
                statusList[i] = statusList[i].trim();
            }
        }
        
        System.debug('*** statusList *** : ' + statusList);
         
     String query = System.Label.Default_Query;

    if (soinstallIds != null && !soinstallIds.isEmpty()) {
        query += ' AND Milestone_Installment__c IN :soinstallIds';
    }

    System.debug('SOI Default Batch Query: ' + query);
     /*   
       String query = 'SELECT Id, Name, Milestone_Installment__c,ExtensionDate__c, MilestoneDate__c, PaymentStatus__c, SalesOrder__c, ' +
                       ' (SELECT Id FROM Invoices__r LIMIT 1) ' +
                       'FROM SalesOrderInstallments__c ' +
                       'WHERE MilestoneDate__c != null ' +
                       'AND PaymentStatus__c != \'Paid\' ' +
                       'AND Default_and_Termination_SR__c = null ' +
                       'AND SalesOrder__r.Status__c NOT IN : statusList ' +
                      // 'AND Exclude_from_Default__c = false ' +
                       //'AND MilestoneDate__c <= :cutoffDate';
                       'AND ( ' +
               '      (ExtensionDate__c != null AND ExtensionDate__c <= :cutoffDate) ' +
               '   OR ( ExtensionDate__c = null AND MilestoneDate__c <= :cutoffDate) ' +
               ')'; 
        */      
        if (soinstallIds != null && !soinstallIds.isEmpty()) {
            query += ' AND Milestone_Installment__c IN :soinstallIds';
        }
        System.debug('nsv query'+query);
         // 3.0 Ends
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SalesOrderInstallments__c> scope) {
        List<SalesOrderInstallments__c> updates = new List<SalesOrderInstallments__c>();
        List<Default_Tracker__c> trackersToUpdate = new List<Default_Tracker__c>();
        List<Process_Flow__c> pf=[Select Id from Process_Flow__c where Name='Default And Termination' LIMIT 1];
        Set<Id> salesOrderIds=new Set<Id>();
        Map<Id, Business_Process__c> salesOrderBPMap=new Map<Id, Business_Process__c>();
        List<SalesOrderInstallments__c> eligibleSOIs = new List<SalesOrderInstallments__c>();
        Date cutoffDate = Date.today().addDays(-10);
        List<AggregateResult> results = [
    SELECT
        SalesOrderInstallment__r.SalesOrder__c SalesOrderId,
        SUM(InvoiceBalance__c) TotalBalance
    FROM Invoice__c
    WHERE SalesOrderInstallment__r.SalesOrder__c = :scope[0].SalesOrder__c
    AND SalesOrderInstallment__r.MilestoneDate__c < TODAY
    AND InvoiceBalance__c > 0
    AND SalesOrderInstallment__r.PaymentStatus__c != 'Cancelled'
    GROUP BY SalesOrderInstallment__r.SalesOrder__c
];
        for(SalesOrderInstallments__c soi:scope){
            if((soi.Invoices__r?.size()>0 && soi.Invoices__r[0].InvoiceBalance__c!=null && soi.Invoices__r[0].InvoiceBalance__c <=500) && !Test.isRunningTest() ){
                  //continue; //outstanding amount less than 500
            }
            if(results.size()>0){
                 Decimal totalBalance = (Decimal) results[0].get('TotalBalance');
                 if(totalBalance<=500){
                    continue;
                 }
            } else {
               continue; 
            }
              Date effectiveDate;
              if (soi.ExtensionDate__c != null && soi.MilestoneDate__c != null) {
        effectiveDate = soi.ExtensionDate__c > soi.MilestoneDate__c
            ? soi.ExtensionDate__c
            : soi.MilestoneDate__c;
    } else if (soi.ExtensionDate__c != null) {
        effectiveDate = soi.ExtensionDate__c;
    } else {
        effectiveDate = soi.MilestoneDate__c;
    }

    if (effectiveDate <= cutoffDate) {
        eligibleSOIs.add(soi);
         if(soi.SalesOrder__c!=null){
                salesOrderIds.add(soi.SalesOrder__c);
        }
    }
           
        }
        if(salesOrderIds.size()>0){
            for (Business_Process__c bp : [
            SELECT Id, Sales_Order__c
            FROM Business_Process__c
            WHERE Type__c = 'Default And Termination'
            AND Sales_Order__c IN :salesOrderIds and Status__c='In Progress'
        ]) {
            salesOrderBPMap.put(bp.Sales_Order__c, bp);
        }
        }

         Map<Id, Default_Tracker__c> trackerMap = new Map<Id, Default_Tracker__c>();

        if (!salesOrderBPMap.isEmpty()) {
            for (Default_Tracker__c dt : [
                SELECT Id, Business_Process__c, Count__c,
                       Sales_Order_Installment_1__c, Sales_Order_Installment_2__c,
                       Sales_Order_Installment_3__c, Sales_Order_Installment_4__c,
                       Sales_Order_Installment_5__c, Sales_Order_Installment_6__c,
                       Sales_Order_Installment_7__c,
                       Invoice_1__c, Invoice_2__c,
                       Invoice_3__c, Invoice_4__c,
                       Invoice_5__c, Invoice_6__c,
                       Invoice_7__c
                FROM Default_Tracker__c
                WHERE Business_Process__c IN :salesOrderBPMap.values()
            ]) {
                trackerMap.put(dt.Business_Process__c, dt);
            }
        }
       
        for (SalesOrderInstallments__c soi : eligibleSOIs) {
            String bpId =null;
            Default_Tracker__c tracker;

            // STEP 1: Get or Create Business Process
            if (salesOrderBPMap.containsKey(soi.SalesOrder__c)) {
                bpId = salesOrderBPMap.get(soi.SalesOrder__c).Id;
            } else {
              if(pf.size()>0)
              bpId= CreateBusinessProcess.createPreRegistration(
                soi.Id,
                pf[0].Id
            );
            }
            if (trackerMap.containsKey(bpId)) {
                tracker = trackerMap.get(bpId);
            } else {
                tracker = new Default_Tracker__c();
                tracker.Business_Process__c = bpId;
                tracker.Count__c = 0;
                insert tracker;
                Business_Process__c bpUpdate=new Business_Process__c();
                bpUpdate.ID=bpId;
                bpUpdate.Default_Tracker__c=tracker.ID;
                update bpUpdate;
                trackerMap.put(bpId, tracker);
            }
             Integer count = (tracker.Count__c == null) ? 0 : Integer.valueOf(tracker.Count__c);
              Integer slot = count + 1;
            String suffix = String.valueOf(slot);
              tracker.put('Sales_Order_Installment_' + suffix + '__c', soi.Id);
               Id invoiceId = null;
            if (soi.Invoices__r != null && !soi.Invoices__r.isEmpty()) {
                invoiceId = soi.Invoices__r[0].Id;
            }

            tracker.put('Invoice_' + suffix + '__c', invoiceId);
             tracker.Count__c = slot;
             trackersToUpdate.add(tracker);
            soi.Default_and_Termination_SR__c = bpId;
            updates.add(soi);
        }

        if (!trackersToUpdate.isEmpty()) {
            update trackersToUpdate;
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Batch Completed');
    }


    public void execute(SchedulableContext sc) {
        Database.executeBatch(new SOIDefaultSRBatch(), 1);
    }
}