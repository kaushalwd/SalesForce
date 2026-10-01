/**********************************************************************************************
 * Name           : UAEDDS_PaymentStatusBatch
 * Description     : Reads back what the bank did with each submitted payment file. Two fixed runs
 *                   a day rather than a short interval poller, because the SLA is fixed - payment
 *                   status is available from 18:00 on the due date and the FT reference from
 *                   06:00 the next morning, so polling in between returns the same answer and
 *                   costs a callout each time. Files still on Submitting are excluded on purpose:
 *                   they have no payment file id to query with, and someone has to establish
 *                   whether the bank holds them before anything is resubmitted.
 * Usage           : Schedule twice daily, after 18:00 and again after 06:00.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 **********************************************************************************************/
public class UAEDDS_PaymentStatusBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {

    private static final Integer SCOPE = 1;

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id, Payment_File_Id__c, Status__c
            FROM DDA_Payment_File__c
            WHERE Payment_File_Id__c != NULL
              AND Status__c IN ('Submitted', 'Partially Settled')
        ]);
    }

    public void execute(Database.BatchableContext context, List<DDA_Payment_File__c> scope) {
        for (DDA_Payment_File__c file : scope) {
            try {
                UAEDDS_PaymentService.refreshFile(file.Id);
            } catch (Exception e) {
                LoggerService.save(LoggerService.createApexLog(
                    e, 'UAEDDS_PaymentStatus', 'UAEDDS_PaymentStatusBatch', 'execute'
                ));
            }
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new UAEDDS_PaymentStatusBatch(), SCOPE);
    }
}