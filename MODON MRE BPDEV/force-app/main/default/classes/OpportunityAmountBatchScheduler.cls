/**********************************************************************************************************************
 * Name               : OpportunityAmountBatchScheduler
 * Description        : Scheduled Batch Apex that sets Opportunity.Amount to the SUM of valid
 *                      SalesOrder__c which are not cancelled or voided. Sum of TotalAmount__c values of each Sales Order having valid
 *                      Sales Orders last modified today, will be populated on Opportunity amount.
 *
 *                      This class implements both Schedulable and Database.Batchable<SObject>.
 *
 * Usage              :
 *                      // To schedule daily at 11:00 PM Dubai time:
 *                      System.schedule(
 *                          OpportunityAmountBatchScheduler.JOB_NAME,
 *                          OpportunityAmountBatchScheduler.CRON_DAILY_11PM_DUBAI,
 *                          new OpportunityAmountBatchScheduler()
 *                      );
 *
 *                      // To execute immediately as a batch:
 *                      Database.executeBatch(
 *                          new OpportunityAmountBatchScheduler(),
 *                          OpportunityAmountBatchScheduler.DEFAULT_BATCH_SIZE
 *                      );
 *
 * Notes              :
 *                      - Salesforce evaluates the cron expression in the time zone of the
 *                        user who schedules the job.
 *                      - The scheduling user must have Asia/Dubai time zone for 23:00 to
 *                        represent 11:00 PM Dubai time.
 *
 * Created By         : Harsh Mathur
 * --------------------------------------------------------------------------------------------------------------------
 * Version  Author                  Date            Comment
 * 1.0      Harsh Mathur         16 Sep 2026     Initial draft
 * 1.1      Harsh Mathur         16 Sep 2026     Exclude cancelled/voided Sales Order statuses
 * 1.2      Narendra Agrawal     17 Sep 2026     Limit Sales Orders to LastModifiedDate = TODAY
 * 1.3      Narendra Agrawal     18 Sep 2026     Combined Schedulable and Batchable implementation
 **********************************************************************************************************************/
public with sharing class OpportunityAmountBatchScheduler implements Database.Batchable<SObject>, Schedulable {

    public static final Integer DEFAULT_BATCH_SIZE = 200;

    public static final String JOB_NAME =
        'Update_Opportunity_Amount_Daily_Job';

    // Seconds Minutes Hours Day_of_month Month Day_of_week
    // 11:00 PM daily in the scheduling user's time zone.
    // Scheduling user must be configured for Asia/Dubai.
    public static final String CRON_DAILY_11PM_DUBAI =
        '0 0 23 * * ?';

    // Sales Orders in these statuses are ignored for Opportunity.Amount.
    public static final List<String> EXCLUDED_STATUSES = new List<String>{
        'Cancelled',
        'Cancelled SR',
        'System cancelled',
        'Property Transfer Cancelled - SR',
        'Property Transfer Title Deed Cancelled - SR',
        'Unit Cancellation Cancelled - SR',
        'Unit Swap Cancelled - SR',
        'Unit Upgrade Cancelled - SR',
        'Unit Consolidation Cancelled - SR',
        'Voided'
    };

    private Boolean historicalMode = false;

    public OpportunityAmountBatchScheduler() {
    }

    public OpportunityAmountBatchScheduler(Boolean historicalMode) {
        this.historicalMode = historicalMode;
    }

    /**
     * Executes the batch when the scheduled job fires.
     */
    public void execute(SchedulableContext sc) {
        Database.executeBatch(
            new OpportunityAmountBatchScheduler(),
            DEFAULT_BATCH_SIZE
        );
    }

    /**
     * Selects Opportunities that have at least one valid Sales Order
     * modified today.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {

        if (historicalMode) {
            return Database.getQueryLocator([
                SELECT Id, Amount
                FROM Opportunity
                WHERE Id IN (
                    SELECT Opportunity__c
                    FROM SalesOrder__c
                    WHERE Opportunity__c != null
                    AND Status__c NOT IN :EXCLUDED_STATUSES
                )
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id, Amount
            FROM Opportunity
            WHERE Id IN (
                SELECT Opportunity__c
                FROM SalesOrder__c
                WHERE Opportunity__c != null
                AND Status__c NOT IN :EXCLUDED_STATUSES
                AND LastModifiedDate = TODAY
            )
        ]);
    }

    /**
     * Calculates the total valid Sales Order amount for each Opportunity
     * and updates Opportunity.Amount only when the value has changed.
     */
    public void execute(
        Database.BatchableContext bc, List<Opportunity> scope
    ) {

        if (scope == null || scope.isEmpty()) {
            return;
        }

        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>();

        for (Opportunity opp : scope) {
            opportunityIds.add(opp.Id);
            opportunitiesById.put(opp.Id, opp);
        }

        Map<Id, Decimal> amountByOpportunityId = new Map<Id, Decimal>();

        for (AggregateResult groupedOrder : [
            SELECT Opportunity__c opportunityId,
                   SUM(TotalAmount__c) totalAmount
            FROM SalesOrder__c
            WHERE Opportunity__c IN :opportunityIds
            AND Opportunity__c != null
            AND Status__c NOT IN :EXCLUDED_STATUSES
            GROUP BY Opportunity__c
        ]) {
            Id opportunityId = (Id) groupedOrder.get('opportunityId');

            if (opportunityId != null) {
                if(groupedOrder.get('totalAmount') != null) {
                    amountByOpportunityId.put(opportunityId, (Decimal) groupedOrder.get('totalAmount'));
                }
            }
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();

        for (Id opportunityId : opportunityIds) {

            // No valid Sales Orders found for this Opportunity.
            if (!amountByOpportunityId.containsKey(opportunityId)) {
                continue;
            }

            Opportunity existingOpp = opportunitiesById.get(opportunityId);

            Decimal amountToUpdate = amountByOpportunityId.get(opportunityId);

            // Do nothing if Opportunity.Amount already has the same calculated amount.
            if (existingOpp != null && existingOpp.Amount == amountToUpdate) {
                continue;
            }

            opportunitiesToUpdate.add(
                new Opportunity(
                    Id = opportunityId,
                    Amount = amountToUpdate
                )
            );
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            Database.update(opportunitiesToUpdate, false);
        }
    }

    public void finish(Database.BatchableContext bc) {
        // No post-processing required.
    }
}