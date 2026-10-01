/**
* @description Batch class to regenerate Invoices for Cancelled Invoice__c records that
*               have a related Sales Order Installment. For each
*               matching Cancelled Invoice, a new Invoice is created under the same
*               Sales Order Installment, with Invoice Date set from the Installment's
*               Milestone Date and remaining fields populated from the Installment
*               (reuses SalesOrderInstallmentTriggerHelper.createInvoice).
*
* @author      Karunakar Pulkam
* @created     06-08-2026
* ------------------------------------------------------------------------------------
* Version  Author      			Date          Comment
* 1.0      Karunakar Pulkam    06-08-2026    Initial Draft
************************************************************************************/
global class OIC_RegenerateCancelledInvoiceBatch implements Database.Batchable<SObject>, Schedulable {

    private static final Integer DEFAULT_BATCH_SIZE = 20;
    private Set<Id> cancelledInvoiceIds;

    // Default constructor (used by Scheduler)
    global OIC_RegenerateCancelledInvoiceBatch() {
        this(null);
    }

    // Parameterized constructor
    global OIC_RegenerateCancelledInvoiceBatch(Set<Id> cancelledInvoiceIds) {
        this.cancelledInvoiceIds = cancelledInvoiceIds;
    }

    // ─── Schedulable ────────────────────────────────────────────────────────────

    global void execute(SchedulableContext sc) {
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_RegenerateCancelledInvoice');
        String scopeStr = oicParams.Value__c;
        Integer batchSize = scopeStr != null ? Integer.valueOf(scopeStr) : DEFAULT_BATCH_SIZE;
        Database.executeBatch(
            new OIC_RegenerateCancelledInvoiceBatch(),
            batchSize
        );
    }

    // ─── Batchable ──────────────────────────────────────────────────────────────

    global Database.QueryLocator start(Database.BatchableContext bc) {
        Date runDate = Date.valueOf(System.Label.INV_CANCELLEDBATCH_RUN_DATE);
        String SOstatusExcludeLst = System.Label.SO_Status_List;
        String MIREExcludelst = System.Label.MIRE_Exclude_List;
        List<String> excludeSourceEntity  = new List<String>{ 'Modon - Egypt' };
        
        List<String> SOExcludedStatuses = new List<String>();
        for (String status : SOstatusExcludeLst.split(',')){
            SOExcludedStatuses.add(status.trim());
        } 
        
        List<String> MIREList = new List<String>();
        for (String c2 : MIREExcludelst.split(',')) {
            if (c2 != null && c2.contains('^')) {
                MIREList.add(c2.replace('^', ',').trim());
            } else {
                MIREList.add(c2.trim());
            }
        }
        
        if (cancelledInvoiceIds != null && !cancelledInvoiceIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id, SalesOrderInstallment__c
                FROM Invoice__c
                WHERE IsCancelled__c = true
                AND SalesOrderInstallment__c != null
                AND SalesOrderInstallment__r.SalesOrder__r.Status__c NOT IN :SOExcludedStatuses
                AND SalesOrderInstallment__r.SalesOrder__r.ProjectName__c NOT IN : MIREList
                AND SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c NOT IN :excludeSourceEntity
                AND Id IN :cancelledInvoiceIds
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, SalesOrderInstallment__c
                FROM Invoice__c
                WHERE IsCancelled__c = true
                AND Cancelled_Date__c >=: runDate
                AND SalesOrderInstallment__c != null
                AND SalesOrderInstallment__r.SalesOrder__r.ProjectName__c NOT IN : MIREList
                AND SalesOrderInstallment__r.SalesOrder__r.Status__c NOT IN :SOExcludedStatuses
                AND SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c NOT IN :excludeSourceEntity
            ]);
        }
    }

    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        Set<Id> soiIds = new Set<Id>();
        for (Invoice__c inv : (List<Invoice__c>) scope) {
            if (inv.SalesOrderInstallment__c != null) {
                soiIds.add(inv.SalesOrderInstallment__c);
            }
        }
        if (soiIds.isEmpty()) return;

        // Exclude any Sales Order Installment that already has an Active (non-cancelled) Invoice
        Set<Id> soiIdsWithActiveInvoice = new Set<Id>();
        for (Invoice__c activeInv : [
            SELECT Id, SalesOrderInstallment__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c IN :soiIds
            AND IsCancelled__c = false
        ]) {
            soiIdsWithActiveInvoice.add(activeInv.SalesOrderInstallment__c);
        }
        soiIds.removeAll(soiIdsWithActiveInvoice);
        if (soiIds.isEmpty()) return;

        List<SalesOrderInstallments__c> soiList = [
            SELECT Id, SalesOrder__c, Milestone__c, Milestone_Egypt_Percent__c,
                   CurrencyIsoCode, InstallmentAmount__c, Maintenance_Fee__c, MilestoneDate__c
            FROM SalesOrderInstallments__c
            WHERE Id IN :soiIds
        ];

        if (soiList.isEmpty()) return;

        try {
            SalesOrderInstallmentTriggerHelper.createInvoice(soiList);
        } catch (Exception ex) {
            LoggerService.save(
                LoggerService.createApexLog(
                    ex,
                    'Regenerate Cancelled Invoice Batch',
                    'OIC_RegenerateCancelledInvoiceBatch',
                    'execute'
                )
            );
        }
    }

    global void finish(Database.BatchableContext bc) {
    }
}