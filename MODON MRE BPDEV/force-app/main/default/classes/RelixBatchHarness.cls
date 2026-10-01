/**
 * RelixBatchHarness - a test-only batch that reads one Relix case row from inside a batch execute, so a test
 * can prove that no Account or Contact write happens there (docs/relix/07 R-c: MODON's triggers start @future
 * callouts, which a batch cannot). Only top-level classes can be batch classes, hence a class of its own.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  26 Sep 2026  Review fix C-17 (docs/relix).
 */
@IsTest
public class RelixBatchHarness implements Database.Batchable<SObject>, Database.AllowsCallouts {

    /** The row the last finished harness read, so a test knows the batch ran. */
    public static Id lastRowRead;

    private final Id rowId;

    /**
     * A harness for one case row.
     * @param rowId the Relix_KYC_Case__c row to read
     */
    public RelixBatchHarness(Id rowId) {
        this.rowId = rowId;
    }

    /**
     * The one row.
     * @param bc the batch context
     * @return the query locator
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([SELECT Id FROM Relix_KYC_Case__c WHERE Id = :rowId WITH SYSTEM_MODE]);
    }

    /**
     * Reads the row through the integration entry point, writes allowed, from inside the batch.
     * @param bc    the batch context
     * @param scope the row
     */
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        RelixKycService.readBatch(new List<Id>{ rowId });
    }

    /**
     * Records that the batch ran.
     * @param bc the batch context
     */
    public void finish(Database.BatchableContext bc) {
        lastRowRead = rowId;
    }
}