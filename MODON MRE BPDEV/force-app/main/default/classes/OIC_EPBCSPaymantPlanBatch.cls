/**
 * @description       : OIC_EPBCSPaymantPlanBatch
 *                      - Pulls SalesOrderInstallments__c payment plan data (with SalesOrder__c, Unit__c, Phase__c,
 *                        Project__c and the related cleared/applied Invoice__c > Allocation__c > Receipt__c chain)
 *                      - Sends the payload to the EPBCS Payment Plan OIC flow via callout
 *                      - Callouts enabled via Database.AllowsCallouts, schedulable via Schedulable
 *
 * @author            : Karunakar Pulkam
 * @Created           : 15-08-2026
 * --------------------------------------------------------------------------------------------------------------------
 * Version   Author              Date          Comment
 * 1.0       Karunakar Pulkam    15-08-2026    Initial Draft
 * 
 ********************************************************************************************************************/
global class OIC_EPBCSPaymantPlanBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful, Schedulable {

    private static final Integer BATCH_SIZE = 500;

    private Date    runDate;
    private Set<Id> processIds;
    private Integer batchesRun = 0;

    /**
     * Description : Initializes batch with no scoping filters (full sync up to today).
     */
    global OIC_EPBCSPaymantPlanBatch() {
    }

    /**
     * Description : Initializes batch with a cut-off date applied to both SalesOrder__r.CreatedDate
     *               and Receipt__r.EBS_Clearing_Date__c, and/or an explicit Set of SalesOrder Ids
     *               to process. When runDate is null the cut-off defaults to today.
     */
    global OIC_EPBCSPaymantPlanBatch(Date runDate, Set<Id> processIds) {
        this.runDate    = runDate;
        this.processIds = processIds;
    }

    /**
     * Description : Resolves the cut-off date used by both the SalesOrder__r.CreatedDate filter
     *               (start) and the Receipt__r.EBS_Clearing_Date__c filter (execute).
     *               Uses the runDate this batch was constructed with, else today.
     */
    private Date getTargetDate() {
        return (runDate != null) ? runDate : Date.today();
    }

    /**
     * Description : Builds the SalesOrderInstallments__c query dynamically, eager-loading the
     *               SalesOrder__c > Unit__c > Phase__c > Project__c chain and the related
     *               Invoices__r (single level - Allocation__c/Receipt__c are resolved in execute()).
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {

        Boolean  hasProcessIds  = (processIds != null && !processIds.isEmpty());
        // CreatedDate is a Datetime - compare against end-of-day so the whole target date is included.
        Datetime targetDateTime = Datetime.newInstance(getTargetDate(), Time.newInstance(23, 59, 59, 0));
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

        String query =
            'SELECT Id, MilestoneNumber__c, InstallmentAmount__c, MilestoneDate__c, ' +
            'PaymentStatus__c, ExtensionDate__c, SalesOrder__c, ' +
            'SalesOrder__r.Unit__c, SalesOrder__r.Unit__r.Name, SalesOrder__r.Unit__r.Building_Name__c, ' +
            'SalesOrder__r.Unit__r.Phase__r.Name, SalesOrder__r.Unit__r.Phase__r.EntityName__c, ' +
            'SalesOrder__r.Unit__r.Phase__r.Project__r.Name, ' +
            '(SELECT Id, Name FROM Invoices__r) ' +
            'FROM SalesOrderInstallments__c ' +
            'WHERE SalesOrder__c != null AND SalesOrder__r.Status__c NOT IN : SOExcludedStatuses AND SalesOrder__r.ProjectName__c NOT IN : MIREList AND SalesOrder__r.Source_Entity__c NOT IN :excludeSourceEntity';

        if (hasProcessIds) {
            query += ' AND SalesOrder__r.Id IN :processIds';
        }
        query += ' AND SalesOrder__r.CreatedDate <= :targetDateTime';

        System.debug('OIC_EPBCSPaymantPlanBatch query: ' + query);
        return Database.getQueryLocator(query);
    }

    /**
     * Description : Maps each SalesOrderInstallments__c scope record to a
     *               OIC_EPBSCPaymentPlanVO.PaymentPlanRecord and sends the callout.
     *               Resolves the latest Cleared/Applied Receipt__c date per Invoice__c via a
     *               separate dynamic query, since it cannot be nested inside the Invoices__r subquery.
     */
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            batchesRun++;
            System.debug('OIC_EPBCSPaymantPlanBatch - batch #' + batchesRun + ' running, scope size: ' + scope.size());

            if (scope.isEmpty()) {
                return;
            }

            List<SalesOrderInstallments__c> soiList = (List<SalesOrderInstallments__c>) scope;

            Set<Id> invoiceIds = new Set<Id>();
            for (SalesOrderInstallments__c soi : soiList) {
                if (soi.Invoices__r != null) {
                    for (Invoice__c inv : soi.Invoices__r) {
                        invoiceIds.add(inv.Id);
                    }
                }
            }

            Map<Id, Date>    invoiceIdToReceiptDate = new Map<Id, Date>();
            Map<Id, Decimal> invoiceIdToAmountPaid  = new Map<Id, Decimal>();
            Date targetDate = getTargetDate();

            if (!invoiceIds.isEmpty()) {
                String allocQuery =
                    'SELECT Invoice__c, AllocationAmount__c, Receipt__r.ReceiptDate__c, Receipt__r.ChequeDate__c, Receipt__r.TransactionDate__c ' +
                    'FROM Allocation__c ' +
                    'WHERE Invoice__c IN :invoiceIds ' +
                    'AND Invoice__r.InvoiceStatus__c != \'Cancelled\' '+
                    'AND Receipt__r.Status__c = \'Cleared\' ' +
                    'AND Receipt__r.AppliedAmount__c > 0 ' +
                    'AND (Receipt__r.EBS_Clearing_Date__c = null OR Receipt__r.EBS_Clearing_Date__c <= :targetDate) ' +
                    'ORDER BY Receipt__r.CreatedDate DESC';

                for (Allocation__c alloc : (List<Allocation__c>) Database.queryWithBinds(
                    allocQuery,
                    new Map<String, Object>{ 'invoiceIds' => invoiceIds, 'targetDate' => targetDate },
                    AccessLevel.SYSTEM_MODE
                )) {
                    Decimal allocAmount = (alloc.AllocationAmount__c == null) ? 0 : alloc.AllocationAmount__c;
                    Decimal runningTotal = invoiceIdToAmountPaid.containsKey(alloc.Invoice__c)
                        ? invoiceIdToAmountPaid.get(alloc.Invoice__c)
                        : 0;
                    invoiceIdToAmountPaid.put(alloc.Invoice__c, runningTotal + allocAmount);

                    if (!invoiceIdToReceiptDate.containsKey(alloc.Invoice__c)) {
                        Date receiptDate = alloc.Receipt__r.ReceiptDate__c;
                        if (receiptDate == null) {
                            receiptDate = alloc.Receipt__r.ChequeDate__c;
                        }
                        if (receiptDate == null && alloc.Receipt__r.TransactionDate__c != null) {
                            receiptDate = alloc.Receipt__r.TransactionDate__c.date();
                        }
                        invoiceIdToReceiptDate.put(alloc.Invoice__c, receiptDate);
                    }
                }
            }

            List<OIC_EPBSCPaymentPlanVO.PaymentPlanRecord> payload =
                new List<OIC_EPBSCPaymentPlanVO.PaymentPlanRecord>();

            for (SalesOrderInstallments__c soi : soiList) {

                SalesOrder__c so      = soi.SalesOrder__r;
                Unit__c       unit    = (so != null)   ? so.Unit__r          : null;
                Phase__c      phase   = (unit != null) ? unit.Phase__r       : null;
                Project__c    project = (phase != null) ? phase.Project__r   : null;

                Decimal amountPaid  = null;
                Date    receiptDate = null;
                String  invoiceName = null;

                if (soi.Invoices__r != null) {
                    for (Invoice__c inv : soi.Invoices__r) {
                        if (invoiceIdToAmountPaid.containsKey(inv.Id)) {
                            amountPaid  = invoiceIdToAmountPaid.get(inv.Id);
                            invoiceName = inv.Name;
                        }
                        if (invoiceIdToReceiptDate.containsKey(inv.Id)) {
                            receiptDate = invoiceIdToReceiptDate.get(inv.Id);
                        }
                        if (receiptDate != null) {
                            break;
                        }
                    }
                }

                OIC_EPBSCPaymentPlanVO.PaymentPlanRecord rec = new OIC_EPBSCPaymentPlanVO.PaymentPlanRecord();
                rec.bu_name             = (phase != null)   ? phase.EntityName__c   : null;
                rec.project_name        = (project != null) ? project.Name          : null;
                rec.phase_name          = (phase != null)   ? phase.Name            : null;
                rec.building_name       = (unit != null)    ? unit.Building_Name__c : null;
                rec.building_id         = null;
                rec.unit_name           = (unit != null)    ? unit.Name             : null;
                rec.unit_id             = (unit != null)    ? unit.Id               : null;
                rec.inst_num            = soi.MilestoneNumber__c;
                rec.inst_id             = soi.Id;
                rec.inst_net_amount     = soi.InstallmentAmount__c;
                rec.due_date            = soi.MilestoneDate__c;
                rec.receipt_date        = receiptDate;
                rec.status              = soi.PaymentStatus__c;
                rec.amount_due_original = soi.InstallmentAmount__c;
                rec.amount_paid         = amountPaid;
                rec.Due_date_extension  = soi.ExtensionDate__c;
                rec.so_id               = soi.SalesOrder__c;
                rec.invoiceName         = invoiceName;

                payload.add(rec);
            }

            OIC_EPBCSPaymentPlanCallout.sendPaymentPlanData(payload);

        } catch (Exception ex) {
            LoggerService.save(
                LoggerService.createApexLog( ex, 'EPBCS Payment Plan API', 'OIC_EPBCSPaymantPlanBatch', 'execute'
                )
            );
        }
    }

    /**
     * Description : Logs batch completion, including how many batches (chunks) ran in this job.
     */
    global void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [
            SELECT TotalJobItems, JobItemsProcessed, NumberOfErrors, Status
            FROM   AsyncApexJob
            WHERE  Id = :bc.getJobId()
        ];

        String summary =
            'Batches run (tracked): ' + batchesRun +
            '; TotalJobItems (batches): ' + job.TotalJobItems +
            '; JobItemsProcessed: ' + job.JobItemsProcessed +
            '; NumberOfErrors: ' + job.NumberOfErrors +
            '; Status: ' + job.Status;

        System.debug('OIC_EPBCSPaymantPlanBatch complete. ' + summary);

        LoggerService.save(
            LoggerService.createAPILog(
                'EPBCS Payment Plan API',
                'OIC_EPBCSPaymantPlanBatch',
                'finish',
                null,
                null,
                summary,
                'Batch Summary Log'
            )
        );
    }

    /**
     * Description : Schedulable entry point - kicks off this batch with the runDate/processIds
     *               this instance was scheduled with, using a batch size of 250.
     */
    global void execute(SchedulableContext sc) {
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_EPBCSPaymantPlan');
        String scopeStr = oicParams.Value__c;
        Integer batchSize = scopeStr != null ? Integer.valueOf(scopeStr) : BATCH_SIZE;
        Database.executeBatch(new OIC_EPBCSPaymantPlanBatch(), batchSize);
    }
}